/* ══════════════════════════════════════════════════════════
   UI.JS — Mouse glow, card hover, micro-interactions
   ══════════════════════════════════════════════════════════ */

document.addEventListener('DOMContentLoaded', () => {
    initMouseGlow();
    initSmoothScrolling();
    initGSAPAnimations();
});

// ── Mouse Glow Effect on Cards ───────────
function initMouseGlow() {
    document.addEventListener('mousemove', (e) => {
        document.querySelectorAll('.card.glass').forEach(card => {
            const rect = card.getBoundingClientRect();
            const x = ((e.clientX - rect.left) / rect.width) * 100;
            const y = ((e.clientY - rect.top) / rect.height) * 100;
            card.style.setProperty('--mouse-x', `${x}%`);
            card.style.setProperty('--mouse-y', `${y}%`);
        });
    });
}

// ── Smooth Scrolling for Nav Links ───────
function initSmoothScrolling() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                e.preventDefault();
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });
}

// ── GSAP Entrance Animations ─────────────
function initGSAPAnimations() {
    if (typeof gsap === 'undefined') return;
    // ScrollTrigger.min.js is loaded via CDN in index.html, but the plugin
    // still has to be registered before `scrollTrigger:` is usable in a
    // tween below -- without this, GSAP doesn't recognize that key as a
    // real plugin, so the scroll-triggered card reveal never activates.
    if (typeof ScrollTrigger !== 'undefined') {
        gsap.registerPlugin(ScrollTrigger);
    }

    // Hero entrance
    gsap.from('.hero-glass', {
        opacity: 0,
        y: 60,
        duration: 1,
        ease: 'power3.out',
        force3D: true
    });

    gsap.from('.hero-title', {
        opacity: 0,
        y: 30,
        duration: 0.8,
        delay: 0.2,
        ease: 'power3.out',
        force3D: true
    });

    gsap.from('.hero-subtitle', {
        opacity: 0,
        y: 20,
        duration: 0.8,
        delay: 0.4,
        ease: 'power3.out',
        force3D: true
    });

    // NOTE: .btn-primary (Evaluate Faculty / Launch Evaluation) is
    // deliberately NOT animated here. Animating `scale` makes GSAP
    // overwrite the element's inline transform, which wipes out the
    // translateZ(0) compositing-layer fix in style.css (an inline style
    // always beats a class rule) -- reintroducing the exact Edge/Chrome
    // "glass panel content fails to paint" bug this fix exists to avoid,
    // this time stuck at opacity:0 instead of just needing a hover to
    // repaint. These two buttons are too functionally important to risk
    // on a decorative entrance animation.

    // Card stagger on scroll. #input-card (sliders + Evaluate button) is
    // deliberately excluded -- it's too functionally critical to depend on
    // a scroll-position trigger firing at the right moment on top of the
    // transform/repaint concerns noted above. force3D on the rest keeps
    // GSAP's own transform writes from dropping the .glass compositing fix.
    gsap.utils.toArray('.card').forEach((card, i) => {
        if (card.id === 'input-card') return;
        gsap.from(card, {
            scrollTrigger: {
                trigger: card,
                start: 'top 85%',
                toggleActions: 'play none none none'
            },
            opacity: 0,
            y: 40,
            duration: 0.5,
            delay: i * 0.1,
            ease: 'power3.out',
            force3D: true
        });
    });
}

// ── Ripple Effect ────────────────────────
document.addEventListener('click', function(e) {
    const rippleBtn = e.target.closest('.btn-ripple');
    if (!rippleBtn) return;

    const ripple = document.createElement('span');
    ripple.className = 'ripple-effect';
    const rect = rippleBtn.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height);
    ripple.style.width = ripple.style.height = `${size}px`;
    ripple.style.left = `${e.clientX - rect.left - size / 2}px`;
    ripple.style.top = `${e.clientY - rect.top - size / 2}px`;
    rippleBtn.appendChild(ripple);
    ripple.addEventListener('animationend', () => ripple.remove());
});

// Add ripple CSS dynamically
const rippleStyle = document.createElement('style');
rippleStyle.textContent = `
    .ripple-effect {
        position: absolute;
        border-radius: 50%;
        background: rgba(255,255,255,0.4);
        transform: scale(0);
        animation: ripple 0.6s ease-out;
        pointer-events: none;
    }
    @keyframes ripple {
        to { transform: scale(4); opacity: 0; }
    }
`;
document.head.appendChild(rippleStyle);
