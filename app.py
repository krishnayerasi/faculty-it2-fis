"""
app.py — Flask web application for IT1 vs IT2 comparison.
"""

import os
import mimetypes
from flask import Flask, render_template, request, jsonify

# Some Windows installs have a registry entry that maps .js to text/plain,
# which makes Flask serve JS files with the wrong Content-Type; a few
# browsers/security setups refuse to execute a <script> with that MIME
# type. Force the correct types explicitly rather than trusting the OS.
mimetypes.add_type('application/javascript', '.js')
mimetypes.add_type('text/css', '.css')

from it1_engine import IT1FacultyEvaluator
from it2_engine import IT2FacultyEvaluator

app = Flask(__name__)
it1 = IT1FacultyEvaluator()
it2 = IT2FacultyEvaluator(delta=6)

# Bumped by hand on each handoff so it's unambiguous, at a glance, whether
# a running instance is actually the latest code -- shown in the page
# footer and at /api/health.
BUILD_VERSION = "2026-08-09.1-reports-print-export-fix"

KPI_NAMES = ('AM', 'SEP', 'CL', 'AC', 'RC')


@app.context_processor
def inject_build_version():
    return dict(build_version=BUILD_VERSION)


@app.context_processor
def inject_asset_version():
    """
    Makes asset_version('js/app.js') available in templates, returning that
    file's own last-modified time as a cache-busting query string. Flask
    doesn't version static files by default, so a browser can go on serving
    a previously-cached app.js/xai.js/etc. even after the file on disk has
    been replaced -- which looks exactly like "the fix didn't take effect."
    Tying the version to each file's mtime means it changes automatically
    whenever that file changes, with no manual bump needed.
    """
    def asset_version(rel_path):
        full_path = os.path.join(app.static_folder, rel_path)
        try:
            return int(os.path.getmtime(full_path))
        except OSError:
            return 0
    return dict(asset_version=asset_version)


def compute_sensitivity(evaluator, AM, SEP, CL, AC, RC, step=10.0):
    """
    Local sensitivity of PerformanceGrade to each KPI, via a symmetric
    finite-difference perturbation (+/- `step`, clipped to the [0, 100]
    domain). For each KPI this holds the other four fixed, nudges that
    one KPI up and down by `step`, and reports how many points the
    final PerformanceGrade moves between those two evaluations.

    This only calls `evaluator.evaluate(...)` -- the same public method
    the API already uses -- so it works for either the IT1 or IT2
    engine as-is, with no changes to it1_engine.py / it2_engine.py.
    Near a domain edge (KPI within `step` of 0 or 100) one side of the
    perturbation clips, which naturally degrades this to a one-sided
    (forward/backward) difference right at the boundary -- that's
    expected, not an error.

    Cost: 2 extra evaluate() calls per KPI (10 total for 5 KPIs),
    ~1-2 ms each, so well under ~20ms added to the request.
    """
    base = {'AM': AM, 'SEP': SEP, 'CL': CL, 'AC': AC, 'RC': RC}
    sensitivity = {}
    for kpi in KPI_NAMES:
        perturbed_up = dict(base)
        perturbed_down = dict(base)
        perturbed_up[kpi] = min(100.0, base[kpi] + step)
        perturbed_down[kpi] = max(0.0, base[kpi] - step)
        grade_up = evaluator.evaluate(**perturbed_up)['PerformanceGrade']
        grade_down = evaluator.evaluate(**perturbed_down)['PerformanceGrade']
        sensitivity[kpi] = round(abs(grade_up - grade_down), 2)
    return sensitivity


@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/evaluate', methods=['POST'])
def evaluate():
    try:
        d = request.get_json(silent=True)
        if d is None:
            return jsonify({'success': False,
                            'error': 'Request body must be JSON with AM, SEP, CL, AC, RC.'}), 400
        AM = max(0, min(100, float(d.get('AM', 0))))
        SEP = max(0, min(100, float(d.get('SEP', 0))))
        CL = max(0, min(100, float(d.get('CL', 0))))
        AC = max(0, min(100, float(d.get('AC', 0))))
        RC = max(0, min(100, float(d.get('RC', 0))))

        it1_result = it1.evaluate(AM, SEP, CL, AC, RC)
        it2_result = it2.evaluate(AM, SEP, CL, AC, RC)
        it1_result['Sensitivity'] = compute_sensitivity(it1, AM, SEP, CL, AC, RC)
        it2_result['Sensitivity'] = compute_sensitivity(it2, AM, SEP, CL, AC, RC)

        return jsonify({'success': True,
                        'inputs': {'AM':AM,'SEP':SEP,'CL':CL,'AC':AC,'RC':RC},
                        'it1': it1_result,
                        'it2': it2_result})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/health')
def health():
    return jsonify({'status': 'healthy', 'build': BUILD_VERSION})

if __name__ == '__main__':
    print("Faculty Evaluation System — http://localhost:5000")
    app.run(debug=True, host='0.0.0.0', port=5000)