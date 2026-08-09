/* ══════════════════════════════════════════════════════════
   APP.JS — Main Application Logic (Production‑Ready)
   ══════════════════════════════════════════════════════════ */

const KPIS = [
    { id: 'AM',  name: 'Academic Management',       short: 'AM' },
    { id: 'SEP', name: 'Student Exam Performance',   short: 'SEP' },
    { id: 'CL',  name: 'Continuous Learning',        short: 'CL' },
    { id: 'AC',  name: 'Activity Coordination',      short: 'AC' },
    { id: 'RC',  name: 'Research Contribution',      short: 'RC' }
];

/* Last successful /api/evaluate response, kept around so the Reports
   tab -- and Print/PDF, Export CSV, Export JSON, which all live there
   -- can still get at it after the user navigates away from the
   Dashboard. Nothing else in the app persisted this anywhere before:
   the fetched `result` in runEvaluation() below was only ever a local
   variable, so once you left the Dashboard tab, whatever renderResults()
   had drawn into #results-container was the *only* copy of it, and
   switching tabs hides that whole section (see initNavigation()). */
let lastEvaluation = null;

/* ── Slider Builder ─────────────────────── */
function buildSliders() {
    const container = document.getElementById('sliders-container');
    if (!container) return;
    container.innerHTML = KPIS.map(kpi => `
        <div class="slider-row">
            <label for="${kpi.id}">${kpi.name} (${kpi.short})</label>
            <input type="range" id="${kpi.id}" name="${kpi.id}" min="0" max="100" value="0"
                   oninput="document.getElementById('${kpi.id}-val').textContent=this.value">
            <div class="slider-value" id="${kpi.id}-val">0</div>
        </div>
    `).join('');
}

/* ── Score Ring (animated SVG) ──────────── */
function createScoreRing(score, color, label) {
    const pct = Math.min(1, Math.max(0, score / 100));
    const circ = 2 * Math.PI * 54;
    const offset = circ * (1 - pct);
    return `
    <div style="text-align:center;margin:16px 0;">
        <div style="position:relative;width:140px;height:140px;margin:0 auto;">
            <svg width="140" height="140" viewBox="0 0 140 140" style="display:block;transform:rotate(-90deg);">
                <circle cx="70" cy="70" r="54" fill="none" stroke="var(--border-color)" stroke-width="8"/>
                <circle cx="70" cy="70" r="54" fill="none" stroke="${color}" stroke-width="8"
                        stroke-dasharray="${circ}" stroke-dashoffset="${offset}" stroke-linecap="round"/>
            </svg>
            <div style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);text-align:center;">
                <div style="font-size:1.8rem;font-weight:800;color:${color};line-height:1;">${score.toFixed(1)}</div>
            </div>
        </div>
        <div style="margin-top:10px;font-size:0.78rem;font-weight:700;color:var(--text-primary);text-transform:uppercase;letter-spacing:0.8px;">${label}</div>
    </div>`;
}

/* ── Label Pill ─────────────────────────── */
function pillClass(label) {
    const map = {
        'Excellent': 'pill-excellent', 'VeryGood': 'pill-verygood', 'Good': 'pill-good',
        'Fair': 'pill-fair', 'Poor': 'pill-poor',
        'VeryHigh': 'pill-excellent', 'High': 'pill-verygood',
        'Moderate': 'pill-good', 'Low': 'pill-poor'
    };
    return map[label] || 'pill-good';
}

/* ── Confidence Badge ───────────────────── */
function confidenceBadge(width) {
    if (width < 10) return '<span class="conf-badge conf-high">🟢 High Confidence</span>';
    if (width < 20) return '<span class="conf-badge conf-moderate">🟡 Moderate Confidence</span>';
    return '<span class="conf-badge conf-low">🔴 Low Confidence</span>';
}

/* IT1 has no uncertainty interval, so its confidence is read off the
   strongest fired Stage-2 rule instead -- same thresholds it1_engine.py
   itself uses (>0.7 High, >0.4 Moderate, else Low). Computed directly
   from Stage2_Rules rather than searching the Explanation text: that
   text also contains term names like "AC=High", so a plain
   .includes('High') can match the wrong word and show the wrong badge. */
function it1ConfidenceBadge(stage2Rules) {
    const maxMu = (stage2Rules && stage2Rules.length)
        ? Math.max(...stage2Rules.map(r => r.firing_strength))
        : 0;
    if (maxMu > 0.7) return '<span class="conf-badge conf-high">🟢 High Confidence</span>';
    if (maxMu > 0.4) return '<span class="conf-badge conf-moderate">🟡 Moderate Confidence</span>';
    return '<span class="conf-badge conf-low">🔴 Low Confidence</span>';
}

/* ── Main Evaluation ────────────────────── */
async function runEvaluation() {
    const container = document.getElementById('results-container');
    const chartsContainer = document.getElementById('charts-container');
    const xaiContainer = document.getElementById('xai-container');

    container.innerHTML = `<div class="card glass"><div class="card-body" style="text-align:center;padding:60px;">
        <div class="spinner"></div><p style="color:var(--text-secondary);">Evaluating faculty profile…</p></div></div>`;
    if (chartsContainer) chartsContainer.style.display = 'none';
    if (xaiContainer) xaiContainer.innerHTML = '';

    const data = {};
    KPIS.forEach(kpi => { data[kpi.id] = parseFloat(document.getElementById(kpi.id).value); });

    try {
        const res = await fetch('/api/evaluate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (result.success) {
            // renderResults writes the actual evaluation first, so it's on
            // screen no matter what happens next.
            renderResults(result);
            if (chartsContainer) chartsContainer.style.display = 'block';

            // Keep the Reports tab in sync with whatever was just evaluated,
            // so it's already populated by the time the user clicks over to
            // it -- see the comment on `lastEvaluation` above.
            lastEvaluation = { inputs: data, it1: result.it1, it2: result.it2, timestamp: new Date() };
            try {
                renderReportSection();
            } catch (reportErr) {
                console.error('Report rendering failed:', reportErr);
            }

            // Charts, XAI, and the entrance animation each depend on a
            // separate CDN library (Chart.js / Chart.js / GSAP). Each gets
            // its own try/catch so if one of those libraries failed to load
            // (blocked network, ad-blocker, slow CDN, etc.), it only loses
            // that one piece instead of throwing away the results above and
            // skipping everything after it -- previously a single failure
            // here replaced the whole results card with a false "Connection
            // error" and silently skipped XAI entirely.
            try {
                if (typeof renderCharts === 'function') renderCharts(data, result);
            } catch (chartErr) {
                console.error('Chart rendering failed:', chartErr);
            }
            try {
                if (typeof renderXAI === 'function') renderXAI(result);
            } catch (xaiErr) {
                console.error('XAI rendering failed:', xaiErr);
            }
            // NOTE: no entrance animation on .result-card. It's also a
            // .glass element, so animating it here would carry the exact
            // same risk described above (GSAP's transform write clobbering
            // the compositing-layer fix, potentially leaving results stuck
            // invisible after rendering correctly) -- and these are the
            // most important thing on the page for the user to actually see.
        } else {
            container.innerHTML = `<div class="card glass"><div class="card-body" style="text-align:center;padding:40px;color:var(--danger);">❌ ${result.error}</div></div>`;
        }
    } catch (err) {
        container.innerHTML = `<div class="card glass"><div class="card-body" style="text-align:center;padding:40px;color:var(--danger);">❌ Connection error. Is the server running?</div></div>`;
    }
}

/* ── Render Results ─────────────────────── */
function renderResults(result) {
    const it1 = result.it1;
    const it2 = result.it2;
    const it2Width = it2.Interval ? it2.Interval[1] - it2.Interval[0] : 0;
    const it2Left  = it2.Interval ? (it2.Interval[0] / 100) * 100 : 0;
    const it2FillW = it2.Interval ? ((it2.Interval[1] - it2.Interval[0]) / 100) * 100 : 0;
    const it2Marker = (it2.PerformanceGrade / 100) * 100;

    document.getElementById('results-container').innerHTML = `
    <div class="results-grid">
        <!-- IT1 Card -->
        <div class="card glass result-card">
            <div class="card-header"><h3>📊 IT1 Type‑1 Baseline</h3><span class="card-badge">Standard Sugeno</span></div>
            <div class="card-body">
                ${createScoreRing(it1.PerformanceGrade, 'var(--it1-color)', 'Performance Grade')}
                <div style="text-align:center;margin:8px 0;"><span class="label-pill ${pillClass(it1.PerformanceLabel)}">${it1.PerformanceLabel}</span></div>
                <div class="metric-list">
                    <div class="metric-item"><span>Teaching Score</span><strong>${it1.TeachingScore} <small>${it1.TeachingLabel}</small></strong></div>
                    <div class="metric-item"><span>Uncertainty Interval</span><strong style="color:#dc2626;">⚠ Not available</strong></div>
                    <div class="metric-item"><span>Confidence</span>${it1ConfidenceBadge(it1.Stage2_Rules)}</div>
                </div>
                <div class="rule-section"><h4>🔍 Top Fired Rules</h4>
                    ${it1.Stage2_Rules.slice(0,2).map(r => `
                        <div class="rule-chip"><span class="hl">Rule #${r.rule_index}</span>: IF Teach=<span class="hl">${r.antecedents[0]}</span>, AC=<span class="hl">${r.antecedents[1]}</span>, RC=<span class="hl">${r.antecedents[2]}</span> → <span class="hl">${r.consequent}</span> (μ=${r.firing_strength.toFixed(3)})</div>
                    `).join('')}
                </div>
            </div>
        </div>
        <!-- IT2 Card -->
        <div class="card glass result-card it2-card">
            <div class="card-header"><h3>🌟 IT2 Interval Type‑2 <span class="it2-badge">Our Model</span></h3><span class="card-badge">Nie‑Tan + KM</span></div>
            <div class="card-body">
                ${createScoreRing(it2.PerformanceGrade, 'var(--it2-color)', 'Performance Grade')}
                <div style="text-align:center;margin:8px 0;"><span class="label-pill ${pillClass(it2.PerformanceLabel)}">${it2.PerformanceLabel}</span></div>
                <div class="metric-list">
                    <div class="metric-item"><span>Teaching Score</span><strong>${it2.TeachingScore} <small>${it2.TeachingLabel}</small></strong></div>
                    <div class="metric-item"><span>Uncertainty Interval</span><strong style="color:var(--it2-color);">[${it2.Interval[0]}, ${it2.Interval[1]}]</strong></div>
                    <div class="metric-item"><span>Confidence</span>${confidenceBadge(it2Width)}</div>
                </div>
                <div class="interval-bar-wrapper">
                    <div class="interval-bar"><div class="interval-fill" style="left:${it2Left}%;width:${it2FillW}%;"></div><div class="interval-marker" style="left:${it2Marker}%;"></div></div>
                    <div class="interval-labels"><span>0</span><span>25</span><span>50</span><span>75</span><span>100</span></div>
                </div>
                <div class="rule-section"><h4>🔍 Top Fired Rules</h4>
                    ${it2.Stage2_Rules.slice(0,2).map(r => `
                        <div class="rule-chip"><span class="hl">Rule #${r.rule_index}</span>: IF Teach=<span class="hl">${r.antecedents[0]}</span>, AC=<span class="hl">${r.antecedents[1]}</span>, RC=<span class="hl">${r.antecedents[2]}</span> → <span class="hl">${r.consequent}</span> (fNT=${r.fNT.toFixed(3)})</div>
                    `).join('')}
                </div>
            </div>
        </div>
    </div>
    <div class="results-grid" style="margin-top:24px;">
        <div class="card glass"><div class="card-header"><h4>🧠 IT1 Reasoning</h4></div><div class="card-body"><pre class="explanation-pre">${it1.Explanation}</pre></div></div>
        <div class="card glass it2-card"><div class="card-header"><h4>🧠 IT2 Reasoning</h4></div><div class="card-body"><pre class="explanation-pre">${it2.Explanation}</pre></div></div>
    </div>`;

    // Inject result-specific styles once
    if (!document.getElementById('result-styles')) {
        const s = document.createElement('style');
        s.id = 'result-styles';
        s.textContent = `
            .results-grid{display:grid;grid-template-columns:1fr 1fr;gap:24px}
            .it2-card{border:2px solid var(--it2-color)}
            .it2-badge{font-size:0.7rem;background:var(--it2-bg);color:var(--it2-color);padding:3px 10px;border-radius:50px;margin-left:8px}
            .metric-list{margin:16px 0}
            .metric-item{display:flex;justify-content:space-between;padding:10px 0;border-bottom:1px solid var(--border-color);font-size:0.88rem}
            .metric-item small{font-weight:400;color:var(--text-secondary)}
            .rule-section{margin-top:16px}
            .rule-section h4{font-size:0.8rem;text-transform:uppercase;letter-spacing:1px;color:var(--text-secondary);margin-bottom:8px}
            .rule-chip{background:var(--bg-primary);border:1px solid var(--border-color);border-radius:8px;padding:8px 12px;font-size:0.8rem;margin:4px 0}
            .rule-chip .hl{color:var(--primary);font-weight:600}
            .interval-bar-wrapper{margin:16px 0}
            .interval-bar{background:#f1f5f9;border-radius:8px;height:24px;position:relative;overflow:hidden}
            .interval-fill{position:absolute;top:0;height:100%;background:linear-gradient(90deg,#a7f3d0,#059669);border-radius:8px;transition:all 0.6s ease}
            .interval-marker{position:absolute;top:-4px;width:3px;height:32px;background:var(--text-primary);border-radius:2px;transition:left 0.6s ease}
            .interval-labels{display:flex;justify-content:space-between;font-size:0.7rem;color:var(--text-tertiary);margin-top:4px}
            .explanation-pre{font-family:'SF Mono','Cascadia Code',monospace;font-size:0.8rem;white-space:pre-wrap;line-height:1.6;background:transparent}
            .label-pill{display:inline-block;padding:4px 16px;border-radius:50px;font-size:0.8rem;font-weight:700}
            .pill-excellent{background:#dcfce7;color:#166534}.pill-verygood{background:#dbeafe;color:#1e40af}.pill-good{background:#fef3c7;color:#92400e}.pill-fair{background:#ffedd5;color:#9a3412}.pill-poor{background:#fee2e2;color:#991b1b}
            .conf-badge{display:inline-flex;align-items:center;gap:6px;padding:4px 12px;border-radius:50px;font-size:0.75rem;font-weight:600}
            .conf-high{background:#dcfce7;color:#166534}.conf-moderate{background:#fef3c7;color:#92400e}.conf-low{background:#fee2e2;color:#991b1b}
            @media(max-width:768px){.results-grid{grid-template-columns:1fr}}
        `;
        document.head.appendChild(s);
    }
}

/* ── Reports ─────────────────────────────
   Renders into #report-content, which sits inside the #reports
   section. This -- not the "Print / PDF" button itself -- is the
   actual fix for PDFs coming out without data: window.print() only
   ever prints what's in the DOM at the time, and previously nothing
   in the app ever put an evaluation's results into the Reports tab.
   Called after every successful evaluation and again whenever the
   Reports nav link is clicked, so it's always showing the latest
   result (or a clear "nothing yet" state instead of a silently blank
   page) no matter which order the user does things in. */
function renderReportSection() {
    const el = document.getElementById('report-content');
    if (!el) return;

    if (!lastEvaluation) {
        el.innerHTML = `
        <div class="card glass">
            <div class="card-body" style="text-align:center;padding:48px 24px;color:var(--text-secondary);">
                <p style="margin-bottom:16px;">No evaluation yet. Run one from the Dashboard, then come back here to view, print, or export the report.</p>
                <button class="btn-secondary" onclick="document.querySelector('.nav-link[data-section=dashboard]').click()">Go to Dashboard →</button>
            </div>
        </div>`;
        return;
    }

    const { inputs, it1, it2, timestamp } = lastEvaluation;
    const it2Width = it2.Interval ? it2.Interval[1] - it2.Interval[0] : 0;

    // Separate sibling cards (not one big wrapper) so each one can carry
    // its own page-break-avoid rule when printed without dragging the
    // whole report along as a single unbreakable block -- see style.css.
    el.innerHTML = `
    <div class="card glass">
        <div class="card-header"><h3>📋 Evaluation Report</h3><span class="card-badge">${timestamp.toLocaleString()}</span></div>
        <div class="card-body">
            <h4 class="report-subhead">Faculty Profile Input</h4>
            <table class="report-table">
                <thead><tr>${KPIS.map(k => `<th>${k.short}</th>`).join('')}</tr></thead>
                <tbody><tr>${KPIS.map(k => `<td>${inputs[k.id]}</td>`).join('')}</tr></tbody>
            </table>

            <h4 class="report-subhead">IT1 vs IT2 Results</h4>
            <table class="report-table">
                <thead><tr><th>Metric</th><th>IT1 · Type‑1</th><th>IT2 · Interval Type‑2</th></tr></thead>
                <tbody>
                    <tr><td>Teaching Score</td><td>${it1.TeachingScore} <small>(${it1.TeachingLabel})</small></td><td>${it2.TeachingScore} <small>(${it2.TeachingLabel})</small></td></tr>
                    <tr><td>Performance Grade</td><td>${it1.PerformanceGrade} <span class="label-pill ${pillClass(it1.PerformanceLabel)}">${it1.PerformanceLabel}</span></td><td>${it2.PerformanceGrade} <span class="label-pill ${pillClass(it2.PerformanceLabel)}">${it2.PerformanceLabel}</span></td></tr>
                    <tr><td>Uncertainty Interval</td><td><strong style="color:var(--danger);">⚠ Not available</strong></td><td>[${it2.Interval[0]}, ${it2.Interval[1]}]</td></tr>
                    <tr><td>Confidence</td><td>${it1ConfidenceBadge(it1.Stage2_Rules)}</td><td>${confidenceBadge(it2Width)}</td></tr>
                </tbody>
            </table>
        </div>
    </div>

    <div class="results-grid" style="margin-top:24px;">
        <div class="card glass"><div class="card-header"><h4>🔍 IT1 Top Fired Rules</h4></div><div class="card-body">
            ${it1.Stage2_Rules.slice(0,2).map(r => `
                <div class="rule-chip"><span class="hl">Rule #${r.rule_index}</span>: IF Teach=<span class="hl">${r.antecedents[0]}</span>, AC=<span class="hl">${r.antecedents[1]}</span>, RC=<span class="hl">${r.antecedents[2]}</span> → <span class="hl">${r.consequent}</span> (μ=${r.firing_strength.toFixed(3)})</div>
            `).join('')}
        </div></div>
        <div class="card glass"><div class="card-header"><h4>🔍 IT2 Top Fired Rules</h4></div><div class="card-body">
            ${it2.Stage2_Rules.slice(0,2).map(r => `
                <div class="rule-chip"><span class="hl">Rule #${r.rule_index}</span>: IF Teach=<span class="hl">${r.antecedents[0]}</span>, AC=<span class="hl">${r.antecedents[1]}</span>, RC=<span class="hl">${r.antecedents[2]}</span> → <span class="hl">${r.consequent}</span> (fNT=${r.fNT.toFixed(3)})</div>
            `).join('')}
        </div></div>
    </div>

    <div class="results-grid" style="margin-top:24px;">
        <div class="card glass"><div class="card-header"><h4>🧠 IT1 Reasoning</h4></div><div class="card-body"><pre class="explanation-pre">${it1.Explanation}</pre></div></div>
        <div class="card glass it2-card"><div class="card-header"><h4>🧠 IT2 Reasoning</h4></div><div class="card-body"><pre class="explanation-pre">${it2.Explanation}</pre></div></div>
    </div>`;

    // Deliberately no entrance animation on any of the cards above, same
    // reasoning as .result-card in renderResults() and .xai-grid .card in
    // xai.js: initGSAPAnimations() only ever runs once, at DOMContentLoaded,
    // against whatever `.card` elements exist at that moment. Everything
    // built by this function is injected via innerHTML well after that (on
    // an evaluation completing, or on opening the Reports tab), so GSAP's
    // one-time query never saw these elements and never gave them the
    // opacity:0 starting state a scroll-triggered reveal needs -- they just
    // render normally. Adding these cards to that query later would risk
    // the same "stuck invisible" failure mode described elsewhere in this
    // codebase, worse here because the Reports section starts as
    // display:none, so ScrollTrigger would have nothing to measure anyway.

    // Report-specific styles, injected once. Rules/badges/pills/explanation
    // text reuse the classes `result-styles` already injected in
    // renderResults() above -- safe because this function only ever
    // reaches this point (real data, not the empty state) after at least
    // one evaluation has already run renderResults() first.
    if (!document.getElementById('report-styles')) {
        const s = document.createElement('style');
        s.id = 'report-styles';
        s.textContent = `
            .report-subhead{font-size:0.8rem;text-transform:uppercase;letter-spacing:1px;color:var(--text-secondary);margin:24px 0 10px}
            .report-subhead:first-child{margin-top:0}
            .report-table{width:100%;border-collapse:collapse;font-size:0.88rem;margin-bottom:8px}
            .report-table th,.report-table td{text-align:left;padding:10px 12px;border-bottom:1px solid var(--border-color)}
            .report-table th{color:var(--text-secondary);font-weight:600;font-size:0.78rem;text-transform:uppercase;letter-spacing:0.4px}
            .report-table td small{color:var(--text-secondary);font-weight:400}
        `;
        document.head.appendChild(s);
    }
}

/* ── Navigation ─────────────────────────── */
function initNavigation() {
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', e => {
            e.preventDefault();
            const secId = link.dataset.section;
            document.querySelectorAll('.section').forEach(s => s.style.display = 'none');
            const target = document.getElementById(secId);
            if (target) {
                target.style.display = 'block';
                target.scrollIntoView({ behavior: 'smooth' });
            }
            if (secId === 'reports' && typeof renderReportSection === 'function') renderReportSection();
            document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
            link.classList.add('active');
        });
    });
}

function scrollToDashboard() {
    const dash = document.getElementById('dashboard');
    if (dash) { dash.style.display = 'block'; dash.scrollIntoView({ behavior: 'smooth' }); }
}

/* ── Theme Toggle ───────────────────────── */
(function() {
    const toggle = document.getElementById('theme-toggle');
    if (!toggle) return;
    toggle.addEventListener('click', () => {
        const html = document.documentElement;
        const cur = html.getAttribute('data-theme');
        const next = cur === 'dark' ? 'light' : 'dark';
        html.setAttribute('data-theme', next);
        localStorage.setItem('theme', next);
    });
    const saved = localStorage.getItem('theme') || 'light';
    document.documentElement.setAttribute('data-theme', saved);
})();

/* ── Export Helpers ─────────────────────── */
// Both previously read the 5 slider values directly off the DOM, so they
// "worked" from any tab but only ever exported the raw inputs -- never the
// computed IT1/IT2 results, which is the part evaluation actually produces.
// They now export lastEvaluation instead, same as the report/print output.
function exportCSV() {
    if (!lastEvaluation) { alert('No evaluation yet — run one from the Dashboard first, then come back to Reports.'); return; }
    const { inputs, it1, it2 } = lastEvaluation;
    const rows = [['Metric', 'IT1 (Type-1)', 'IT2 (Interval Type-2)']];
    KPIS.forEach(k => rows.push([`Input: ${k.name}`, inputs[k.id], inputs[k.id]]));
    rows.push(['Teaching Score', it1.TeachingScore, it2.TeachingScore]);
    rows.push(['Teaching Label', it1.TeachingLabel, it2.TeachingLabel]);
    rows.push(['Performance Grade', it1.PerformanceGrade, it2.PerformanceGrade]);
    rows.push(['Performance Label', it1.PerformanceLabel, it2.PerformanceLabel]);
    rows.push(['Uncertainty Interval', 'N/A', it2.Interval ? `[${it2.Interval[0]}, ${it2.Interval[1]}]` : 'N/A']);
    const csv = rows.map(r => r.map(v => `"${String(v).replace(/"/g, '""')}"`).join(',')).join('\n');
    downloadFile('faculty-evaluation-report.csv', 'text/csv', csv);
}
function exportJSON() {
    if (!lastEvaluation) { alert('No evaluation yet — run one from the Dashboard first, then come back to Reports.'); return; }
    downloadFile('faculty-evaluation-report.json', 'application/json', JSON.stringify(lastEvaluation, null, 2));
}
function downloadFile(name, type, content) {
    const blob = new Blob([content], { type });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = name; a.click();
    URL.revokeObjectURL(url);
}