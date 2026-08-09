/* ══════════════════════════════════════════════════════════
   CHARTS.JS — Radar, Gauge, Comparison Charts
   ══════════════════════════════════════════════════════════ */

let radarChart = null, gaugeChart = null, comparisonChart = null;

function renderCharts(inputData, result) {
    if (typeof Chart === 'undefined') {
        // Chart.js CDN didn't load -- say so honestly instead of throwing
        // (which, uncaught, used to cascade into losing the results/XAI too).
        document.querySelectorAll('#radarChart, #gaugeChart, #comparisonChart').forEach(canvas => {
            const body = canvas.closest('.card-body');
            if (body) body.innerHTML = '<p style="text-align:center;color:var(--text-tertiary);font-size:0.85rem;padding:24px 8px;">📉 Chart unavailable — Chart.js failed to load. Check your internet connection and reload.</p>';
        });
        return;
    }
    renderRadar(inputData);
    renderGauge(result.it2.PerformanceGrade, result.it2.Interval);
    renderComparison(result);
}

function renderRadar(data) {
    const ctx = document.getElementById('radarChart')?.getContext('2d');
    if (!ctx) return;
    if (radarChart) radarChart.destroy();
    radarChart = new Chart(ctx, {
        type: 'radar',
        data: {
            labels: ['Academic Mgmt','Student Exam','Continuous Learn','Activity Coord','Research Contrib'],
            datasets: [{
                label: 'KPI Scores',
                data: [data.AM, data.SEP, data.CL, data.AC, data.RC],
                backgroundColor: 'rgba(37,99,235,0.2)',
                borderColor: '#2563eb',
                borderWidth: 2,
                pointRadius: 4
            }]
        },
        options: {
            responsive: true,
            scales: { r: { beginAtZero: true, max: 100, ticks: { stepSize: 20 } } },
            plugins: { legend: { display: false } }
        }
    });
}

function renderGauge(score, interval) {
    const ctx = document.getElementById('gaugeChart')?.getContext('2d');
    if (!ctx) return;
    if (gaugeChart) gaugeChart.destroy();
    const label = interval ? `[${interval[0]}, ${interval[1]}]` : '';
    gaugeChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            datasets: [{
                data: [score, 100 - score],
                backgroundColor: ['#059669', '#e2e8f0'],
                borderWidth: 0,
                circumference: 270,
                rotation: 225
            }]
        },
        options: {
            cutout: '75%',
            plugins: { legend: { display: false }, tooltip: { enabled: false } }
        },
        plugins: [{
            id: 'gaugeText',
            afterDraw(chart) {
                const { ctx, width, height } = chart;
                ctx.save();
                ctx.font = 'bold 28px Inter'; ctx.fillStyle = '#0f172a'; ctx.textAlign = 'center';
                ctx.fillText(score.toFixed(1), width/2, height/2 - 4);
                ctx.font = '11px Inter'; ctx.fillStyle = '#64748b';
                ctx.fillText(label, width/2, height/2 + 24);
                ctx.restore();
            }
        }]
    });
}

function renderComparison(result) {
    const ctx = document.getElementById('comparisonChart')?.getContext('2d');
    if (!ctx) return;
    if (comparisonChart) comparisonChart.destroy();
    comparisonChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['Teaching Score', 'Performance Grade'],
            datasets: [
                { label: 'IT1', data: [result.it1.TeachingScore, result.it1.PerformanceGrade], backgroundColor: 'rgba(234,88,12,0.7)', borderRadius: 8 },
                { label: 'IT2', data: [result.it2.TeachingScore, result.it2.PerformanceGrade], backgroundColor: 'rgba(5,150,105,0.7)', borderRadius: 8 }
            ]
        },
        options: {
            responsive: true,
            scales: { y: { beginAtZero: true, max: 100 } },
            plugins: { legend: { position: 'bottom' } }
        }
    });
}