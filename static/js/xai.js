/* ══════════════════════════════════════════════════════════
   XAI.JS — Explainable AI Visualizations
   ══════════════════════════════════════════════════════════ */

let contribChart = null;

function renderXAI(result) {
    const container = document.getElementById('xai-container');
    if (!container) return;
    const it2 = result.it2;
    const mems = it2.Memberships || {};
    const s1 = it2.Stage1_Rules || [];
    const s2 = it2.Stage2_Rules || [];

    container.innerHTML = `
    <div class="xai-grid">
        <div class="card glass"><div class="card-header"><h3>🔀 Rule Activation Flow</h3></div><div class="card-body">
            <div class="timeline-stage"><div class="stage-label">Stage 1 (Teaching)</div>
                ${s1.slice(0,4).map(r => `<div class="flow-rule"><span>${r.antecedents.join(', ')}</span> → <strong>${r.consequent}</strong> <small>(${(r.fNT||r.firing_strength||0).toFixed(3)})</small></div>`).join('')}
            </div>
            <div class="timeline-connector"></div>
            <div class="timeline-stage"><div class="stage-label">Stage 2 (Performance)</div>
                ${s2.slice(0,4).map(r => `<div class="flow-rule"><span>${r.antecedents.join(', ')}</span> → <strong>${r.consequent}</strong> <small>(${(r.fNT||r.firing_strength||0).toFixed(3)})</small></div>`).join('')}
            </div>
        </div></div>
        <div class="card glass"><div class="card-header"><h3>📊 Membership Degrees</h3></div><div class="card-body" id="membership-container"></div></div>
        <div class="card glass"><div class="card-header"><h3>📈 Input Contribution</h3></div><div class="card-body"><canvas id="contributionChart"></canvas></div></div>
        <div class="card glass"><div class="card-header"><h3>🛡️ Decision Confidence</h3></div><div class="card-body">
            <div class="confidence-meter"><div class="meter-fill" style="width:${Math.max(0,100-(it2.Interval?it2.Interval[1]-it2.Interval[0]:0)*2)}%"></div></div>
            <div class="confidence-details"><span>Width: ${it2.Interval?(it2.Interval[1]-it2.Interval[0]).toFixed(1):'N/A'} pts</span><span>${it2.Interval&&(it2.Interval[1]-it2.Interval[0])<10?'High':it2.Interval&&(it2.Interval[1]-it2.Interval[0])<20?'Moderate':'Low'} Confidence</span></div>
        </div></div>
    </div>`;

    /* Membership bars */
    const memContainer = document.getElementById('membership-container');
    if (memContainer) {
        memContainer.innerHTML = Object.entries(mems).map(([kpi, terms]) => `
            <div class="membership-item"><div class="membership-label">${kpi}</div>
                ${Object.entries(terms).map(([term, val]) => {
                    const mu = Array.isArray(val) ? (val[0]+val[1])/2 : val;
                    const pct = (mu*100).toFixed(0);
                    const color = mu>0.7?'#059669':mu>0.4?'#f59e0b':'#ea580c';
                    return `<div class="membership-bar-row"><span>${term}</span><div class="bar-track"><div class="bar-fill" style="width:${pct}%;background:${color};"></div></div><span>${mu.toFixed(2)}</span></div>`;
                }).join('')}
            </div>`).join('');
    }

    /* Contribution chart — real local sensitivity from the API (points of
       PerformanceGrade movement for a +/-10 nudge on each KPI), not a
       fixed placeholder. Falls back to zeros only if the field is ever
       missing, so the chart still renders instead of breaking. */
    const ctx = document.getElementById('contributionChart')?.getContext('2d');
    if (ctx && typeof Chart === 'undefined') {
        // Chart.js CDN didn't load. Say so honestly rather than throwing --
        // an uncaught throw here used to abort the rest of this function
        // (including the entrance animation below) even though everything
        // above (rule flow, membership bars) had already rendered fine.
        ctx.canvas.outerHTML = '<p style="text-align:center;color:var(--text-tertiary);font-size:0.85rem;padding:16px 8px;">📉 Chart unavailable — Chart.js failed to load.</p>';
    } else if (ctx) {
        if (contribChart) contribChart.destroy();
        const sens = it2.Sensitivity || {};
        const kpiOrder = ['AM', 'SEP', 'CL', 'AC', 'RC'];
        contribChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: kpiOrder,
                datasets: [{
                    label: 'Influence (pts)',
                    data: kpiOrder.map(k => sens[k] ?? 0),
                    backgroundColor: ['#2563eb','#2563eb','#2563eb','#059669','#059669'],
                    borderRadius: 8
                }]
            },
            options: {
                indexAxis: 'y',
                responsive: true,
                scales: { x: { beginAtZero: true } },
                plugins: { legend: { display: false } }
            }
        });
    }

    // NOTE: no entrance animation here either, for the same reason as the
    // result cards in app.js -- .xai-grid .card elements are .glass too,
    // and this is the XAI output itself.
}

/* XAI‑specific styles (injected once) */
(function() {
    if (document.getElementById('xai-styles')) return;
    const s = document.createElement('style');
    s.id = 'xai-styles';
    s.textContent = `
        .xai-grid{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-top:16px}
        .timeline-stage{background:var(--bg-primary);border-radius:var(--radius-sm);padding:14px}
        .stage-label{font-weight:700;font-size:0.85rem;margin-bottom:10px;color:var(--primary)}
        .flow-rule{display:flex;align-items:center;gap:8px;padding:4px 0;font-size:0.8rem;border-bottom:1px solid var(--border-color)}
        .flow-rule strong{color:var(--primary)}
        .timeline-connector{width:2px;height:20px;background:var(--primary);opacity:0.3;margin:0 auto}
        .membership-item{border-bottom:1px solid var(--border-color);padding-bottom:8px;margin-bottom:8px}
        .membership-label{font-weight:600;font-size:0.85rem;margin-bottom:4px}
        .membership-bar-row{display:flex;align-items:center;gap:8px;margin:3px 0}
        .membership-bar-row span:first-child{width:70px;font-size:0.75rem;color:var(--text-secondary)}
        .bar-track{flex:1;height:12px;background:#f1f5f9;border-radius:6px;overflow:hidden}
        .bar-fill{height:100%;border-radius:6px;transition:width 0.6s ease}
        .confidence-meter{height:12px;background:#f1f5f9;border-radius:6px;overflow:hidden;margin-bottom:8px}
        .meter-fill{height:100%;background:linear-gradient(90deg,#ef4444,#f59e0b,#16a34a);border-radius:6px;transition:width 0.6s ease}
        .confidence-details{display:flex;justify-content:space-between;font-size:0.8rem;color:var(--text-secondary)}
        @media(max-width:768px){.xai-grid{grid-template-columns:1fr}}
    `;
    document.head.appendChild(s);
})();
