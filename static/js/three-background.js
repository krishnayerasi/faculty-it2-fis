/* ══════════════════════════════════════════════════════════
   THREE-BACKGROUND.JS — 3D Neural Network Background
   ══════════════════════════════════════════════════════════ */

let scene, camera, renderer, particles, lines, animFrame;

function initThreeBackground() {
    const canvas = document.getElementById('bg-canvas');
    if (!canvas || typeof THREE === 'undefined') return;
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(75, window.innerWidth/window.innerHeight, 0.1, 1000);
    camera.position.z = 30;
    renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

    const pCount = 200;
    const pGeom = new THREE.BufferGeometry();
    const pPos = new Float32Array(pCount * 3), pCol = new Float32Array(pCount * 3);
    for (let i = 0; i < pCount * 3; i += 3) {
        pPos[i] = (Math.random() - 0.5) * 60;
        pPos[i+1] = (Math.random() - 0.5) * 40;
        pPos[i+2] = (Math.random() - 0.5) * 30;
        pCol[i] = 0.1 + Math.random() * 0.1;
        pCol[i+1] = 0.3 + Math.random() * 0.4;
        pCol[i+2] = 0.5 + Math.random() * 0.4;
    }
    pGeom.setAttribute('position', new THREE.BufferAttribute(pPos, 3));
    pGeom.setAttribute('color', new THREE.BufferAttribute(pCol, 3));
    particles = new THREE.Points(pGeom, new THREE.PointsMaterial({ size: 0.15, vertexColors: true, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }));
    scene.add(particles);

    const lCount = 80;
    const lPos = new Float32Array(lCount * 6), lCol = new Float32Array(lCount * 6);
    for (let i = 0; i < lCount; i++) {
        const a = Math.floor(Math.random() * pCount), b = Math.floor(Math.random() * pCount);
        for (let j = 0; j < 3; j++) {
            lPos[i*6+j] = pPos[a*3+j];
            lPos[i*6+3+j] = pPos[b*3+j];
        }
        lCol[i*6+0] = 0.15; lCol[i*6+1] = 0.4; lCol[i*6+2] = 0.6;
        lCol[i*6+3] = 0.15; lCol[i*6+4] = 0.4; lCol[i*6+5] = 0.6;
    }
    const lGeom = new THREE.BufferGeometry();
    lGeom.setAttribute('position', new THREE.BufferAttribute(lPos, 3));
    lGeom.setAttribute('color', new THREE.BufferAttribute(lCol, 3));
    lines = new THREE.LineSegments(lGeom, new THREE.LineBasicMaterial({ vertexColors: true, transparent: true, opacity: 0.15, blending: THREE.AdditiveBlending, depthWrite: false }));
    scene.add(lines);

    function animate() {
        animFrame = requestAnimationFrame(animate);
        if (particles) { particles.rotation.y += 0.0003; particles.rotation.x += 0.0001; }
        if (lines) { lines.rotation.y += 0.0003; lines.rotation.x += 0.0001; }
        renderer.render(scene, camera);
    }
    animate();
    window.addEventListener('resize', () => {
        if (!camera || !renderer) return;
        camera.aspect = window.innerWidth / window.innerHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(window.innerWidth, window.innerHeight);
    });
}
window.addEventListener('beforeunload', () => {
    if (animFrame) cancelAnimationFrame(animFrame);
    if (renderer) renderer.dispose();
});
