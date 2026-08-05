"""
app.py — Flask web application for IT1 vs IT2 comparison.
"""

from flask import Flask, render_template, request, jsonify
from it1_engine import IT1FacultyEvaluator
from it2_engine import IT2FacultyEvaluator

app = Flask(__name__)
it1 = IT1FacultyEvaluator()
it2 = IT2FacultyEvaluator(delta=6)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/evaluate', methods=['POST'])
def evaluate():
    try:
        d = request.get_json()
        AM = max(0, min(100, float(d.get('AM', 0))))
        SEP = max(0, min(100, float(d.get('SEP', 0))))
        CL = max(0, min(100, float(d.get('CL', 0))))
        AC = max(0, min(100, float(d.get('AC', 0))))
        RC = max(0, min(100, float(d.get('RC', 0))))
        return jsonify({'success': True,
                        'inputs': {'AM':AM,'SEP':SEP,'CL':CL,'AC':AC,'RC':RC},
                        'it1': it1.evaluate(AM,SEP,CL,AC,RC),
                        'it2': it2.evaluate(AM,SEP,CL,AC,RC)})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    print("Faculty Evaluation System — http://localhost:5000")
    app.run(debug=True, host='0.0.0.0', port=5000)