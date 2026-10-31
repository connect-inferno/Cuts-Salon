import { Suspense, useEffect, useMemo, useRef, useState } from 'react';
import * as THREE from 'three';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Environment, Lightformer, Text, useTexture, PerformanceMonitor } from '@react-three/drei';
import { stage, pointer, SCREENS } from './stage';
import { WHATSAPP_PATH } from '../WhatsAppIcon';

// Phone proportions. The screen matches the app screenshots (540 x 873).
const SCREEN_H = 3.0;
const SCREEN_W = SCREEN_H * (540 / 873);
const BODY_W = SCREEN_W + 0.18;
const BODY_H = SCREEN_H + 0.18;
const BODY_D = 0.17;

const { damp } = THREE.MathUtils;

function roundedRect(w, h, r) {
  const s = new THREE.Shape();
  const x = -w / 2;
  const y = -h / 2;
  s.moveTo(x + r, y);
  s.lineTo(x + w - r, y);
  s.quadraticCurveTo(x + w, y, x + w, y + r);
  s.lineTo(x + w, y + h - r);
  s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  s.lineTo(x + r, y + h);
  s.quadraticCurveTo(x, y + h, x, y + h - r);
  s.lineTo(x, y + r);
  s.quadraticCurveTo(x, y, x + r, y);
  return s;
}

// A slab with large rounded corners and softly bevelled edges, centred on
// the origin (RoundedBox can't do corners bigger than half its depth).
function slab(w, h, d, r, bevel, curve) {
  const g = new THREE.ExtrudeGeometry(roundedRect(w - bevel * 2, h - bevel * 2, r - bevel), {
    depth: d - bevel * 2,
    bevelEnabled: true,
    bevelThickness: bevel,
    bevelSize: bevel,
    bevelSegments: curve > 16 ? 5 : 3,
    curveSegments: curve,
  });
  g.translate(0, 0, -(d - bevel * 2) / 2);
  g.computeVertexNormals();
  return g;
}

const screenVertex = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

// Two screenshots with a soft top-to-bottom wipe between them, clipped to a
// rounded rectangle, plus a faint moving glass reflection.
const screenFragment = /* glsl */ `
  uniform sampler2D mapA;
  uniform sampler2D mapB;
  uniform float mixT;
  uniform vec2 size;
  uniform float radius;
  uniform float glare;
  varying vec2 vUv;

  float sdRoundRect(vec2 p, vec2 h, float r) {
    vec2 q = abs(p) - h + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
  }

  void main() {
    vec2 p = (vUv - 0.5) * size;
    float d = sdRoundRect(p, size * 0.5, radius);
    float aa = fwidth(d);
    float alpha = 1.0 - smoothstep(-aa, aa, d);

    vec3 a = texture2D(mapA, vUv).rgb;
    vec3 b = texture2D(mapB, vUv).rgb;
    float m = smoothstep(0.0, 1.0, mixT * 1.5 - (1.0 - vUv.y) * 0.5);
    // the incoming screen slides in from slightly below
    vec3 bShift = texture2D(mapB, vUv + vec2(0.0, (1.0 - m) * 0.04)).rgb;
    vec3 col = mix(a, bShift, m);

    float band = 1.0 - abs((vUv.x * 0.6 + vUv.y) - glare) * 4.0;
    col += clamp(band, 0.0, 1.0) * 0.06;

    gl_FragColor = vec4(col, alpha);
    #include <colorspace_fragment>
  }
`;

function Phone({ quality }) {
  const group = useRef();
  const screenMat = useRef();
  const textures = useTexture(SCREENS.map((s) => `/screens/${s}.jpg`));
  const gl = useThree((s) => s.gl);

  useMemo(() => {
    const aniso = Math.min(8, gl.capabilities.getMaxAnisotropy());
    textures.forEach((t) => {
      t.colorSpace = THREE.SRGBColorSpace;
      t.anisotropy = aniso;
      t.generateMipmaps = true;
      t.minFilter = THREE.LinearMipmapLinearFilter;
      t.needsUpdate = true;
    });
  }, [textures, gl]);

  const uniforms = useMemo(
    () => ({
      mapA: { value: textures[0] },
      mapB: { value: textures[1] ?? textures[0] },
      mixT: { value: 0 },
      size: { value: new THREE.Vector2(SCREEN_W, SCREEN_H) },
      radius: { value: 0.22 },
      glare: { value: 0.4 },
    }),
    [textures],
  );

  useFrame((state, dt) => {
    const g = group.current;
    if (!g) return;
    const { width, height } = state.viewport;
    // reduced motion: jump straight to the target instead of easing
    const d = stage.still ? 1 : Math.min(dt, 1 / 20);
    const enter = stage.enter;

    const tx = stage.x * width;
    const ty = stage.y * height - (1 - enter) * height * 0.9;
    g.position.x = damp(g.position.x, tx, 6, d);
    g.position.y = damp(g.position.y, ty, 6, d);

    const targetRotY = stage.rotY + stage.spin * Math.PI * 2 - (1 - enter) * 1.4 + pointer.x * 0.12;
    const targetRotX = stage.rotX + (1 - enter) * 0.5 - pointer.y * 0.08;
    g.rotation.y = damp(g.rotation.y, targetRotY, 5, d);
    g.rotation.x = damp(g.rotation.x, targetRotX, 5, d);
    g.rotation.z = damp(g.rotation.z, stage.rotZ, 5, d);

    // keep the phone a sensible share of the viewport height
    const fit = Math.min(1, (height * 0.62) / BODY_H, (width * 0.9) / BODY_W);
    const s = stage.scale * fit;
    g.scale.setScalar(damp(g.scale.x, s, 6, d));
    if (!stage.still) g.position.y += Math.sin(state.clock.elapsedTime * 0.8) * 0.004; // idle bob

    const n = textures.length;
    const sc = THREE.MathUtils.clamp(stage.screen, 0, n - 1);
    const i = Math.min(Math.floor(sc), n - 2);
    uniforms.mapA.value = textures[Math.max(0, i)];
    uniforms.mapB.value = textures[Math.max(0, i) + 1] ?? textures[n - 1];
    uniforms.mixT.value = sc - Math.max(0, i);
    uniforms.glare.value = 0.9 + g.rotation.y * 0.8;
  });

  const geo = useMemo(() => {
    const curve = quality === 'high' ? 24 : 12;
    return {
      body: slab(BODY_W, BODY_H, BODY_D, 0.3, 0.035, curve),
      glass: new THREE.ShapeGeometry(roundedRect(BODY_W - 0.05, BODY_H - 0.05, 0.27), curve),
      camera: slab(0.6, 0.6, 0.05, 0.16, 0.012, curve),
    };
  }, [quality]);
  useEffect(() => () => Object.values(geo).forEach((g) => g.dispose()), [geo]);

  return (
    <group ref={group} position={[0, -6, 0]}>
      {/* titanium body */}
      <mesh geometry={geo.body}>
        <meshPhysicalMaterial color="#1b2638" metalness={0.85} roughness={0.3} clearcoat={1} clearcoatRoughness={0.25} envMapIntensity={1.2} />
      </mesh>
      {/* black glass front */}
      <mesh geometry={geo.glass} position={[0, 0, BODY_D / 2 + 0.001]}>
        <meshPhysicalMaterial color="#05080d" roughness={0.08} metalness={0.1} clearcoat={1} envMapIntensity={0.6} />
      </mesh>
      {/* screen */}
      <mesh position={[0, 0, BODY_D / 2 + 0.004]}>
        <planeGeometry args={[SCREEN_W, SCREEN_H]} />
        <shaderMaterial ref={screenMat} uniforms={uniforms} vertexShader={screenVertex} fragmentShader={screenFragment} transparent toneMapped={false} />
      </mesh>
      {/* side buttons */}
      <mesh position={[BODY_W / 2 + 0.008, 0.55, 0]}>
        <boxGeometry args={[0.02, 0.42, 0.06]} />
        <meshStandardMaterial color="#26344a" metalness={0.9} roughness={0.3} />
      </mesh>
      <mesh position={[-BODY_W / 2 - 0.008, 0.75, 0]}>
        <boxGeometry args={[0.02, 0.22, 0.06]} />
        <meshStandardMaterial color="#26344a" metalness={0.9} roughness={0.3} />
      </mesh>
      {/* camera module on the back */}
      <group position={[-BODY_W / 2 + 0.42, BODY_H / 2 - 0.42, -BODY_D / 2 - 0.02]}>
        <mesh geometry={geo.camera}>
          <meshPhysicalMaterial color="#223049" metalness={0.7} roughness={0.25} clearcoat={1} />
        </mesh>
        {[[-0.13, 0.13], [0.13, -0.13]].map(([x, y]) => (
          <mesh key={x} position={[x, y, -0.035]} rotation-x={Math.PI / 2}>
            <cylinderGeometry args={[0.1, 0.1, 0.03, 32]} />
            <meshPhysicalMaterial color="#04060a" roughness={0.05} metalness={0.5} clearcoat={1} />
          </mesh>
        ))}
      </group>
      <Text
        font="/fonts/PlusJakartaSans-800.ttf"
        fontSize={0.16}
        letterSpacing={0.3}
        position={[0, -0.2, -BODY_D / 2 - 0.002]}
        rotation-y={Math.PI}
        color="#3a4d6b"
        anchorX="center"
        anchorY="middle"
      >
        STYLUX
      </Text>
    </group>
  );
}

// Small UI cards that float around the phone in the hero.
const CHIPS = [
  { title: 'INV-0009 · ₹712', sub: 'Paid by UPI', glyph: '₹', tone: '#15803d', toneBg: '#f0fdf4', pos: [-1.1, 1.25, 0.6] },
  { title: 'Receipt sent', sub: 'on WhatsApp · just now', glyph: 'whatsapp', tone: '#1f9d55', toneBg: '#eafaf0', pos: [1.45, 0.6, 0.8] },
  { title: 'Clocked in 10:20 AM', sub: 'Location saved', glyph: '●', tone: '#1e3a5f', toneBg: '#eef2f7', pos: [-1.15, -0.6, 0.7] },
  { title: '2 birthdays this week', sub: 'Wishes go out at 10 AM', glyph: '★', tone: '#d97706', toneBg: '#fffbeb', pos: [1.35, -1.2, 0.4] },
];

function chipTexture({ title, sub, glyph, tone, toneBg }) {
  const W = 720;
  const H = 200;
  const c = document.createElement('canvas');
  c.width = W;
  c.height = H;
  const ctx = c.getContext('2d');
  const r = 44;
  ctx.beginPath();
  ctx.roundRect(4, 4, W - 8, H - 8, r);
  ctx.fillStyle = 'rgba(255,255,255,0.97)';
  ctx.fill();
  ctx.lineWidth = 3;
  ctx.strokeStyle = '#e6e9ef';
  ctx.stroke();
  // icon tile
  ctx.beginPath();
  ctx.roundRect(36, 44, 112, 112, 30);
  ctx.fillStyle = toneBg;
  ctx.fill();
  ctx.fillStyle = tone;
  if (glyph === 'whatsapp') {
    // the 24-unit logo path, scaled to 56px and centred in the tile
    ctx.save();
    ctx.translate(64, 72);
    ctx.scale(56 / 24, 56 / 24);
    ctx.fill(new Path2D(WHATSAPP_PATH));
    ctx.restore();
  } else {
    ctx.font = '700 56px "Plus Jakarta Sans", sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(glyph, 92, 102);
  }
  ctx.textAlign = 'left';
  ctx.textBaseline = 'alphabetic';
  ctx.fillStyle = '#0f172a';
  ctx.font = '700 44px "Plus Jakarta Sans", sans-serif';
  ctx.fillText(title, 180, 96);
  ctx.fillStyle = '#667085';
  ctx.font = '500 34px "Plus Jakarta Sans", sans-serif';
  ctx.fillText(sub, 180, 146);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}

function Chips({ small }) {
  const group = useRef();
  const items = useMemo(
    () => CHIPS.filter((c) => !(small && c.desktopOnly)).map((c) => ({ ...c, tex: chipTexture(c) })),
    [small],
  );
  const mats = useRef([]);
  const meshes = useRef([]);

  useEffect(() => () => items.forEach((i) => i.tex.dispose()), [items]);

  useFrame((state, dt) => {
    const g = group.current;
    if (!g) return;
    const { width, height } = state.viewport;
    const d = stage.still ? 1 : Math.min(dt, 1 / 20);
    const show = stage.chips * stage.enter;
    g.position.x = damp(g.position.x, stage.x * width, 5, d);
    g.position.y = damp(g.position.y, stage.y * height, 5, d);
    const fit = Math.min(1, (height * 0.62) / BODY_H, (width * 0.9) / BODY_W) * (small ? 0.8 : 1);
    g.scale.setScalar(fit * stage.scale);
    g.rotation.y = damp(g.rotation.y, pointer.x * 0.2, 3, d);
    g.rotation.x = damp(g.rotation.x, -pointer.y * 0.1, 3, d);
    const t = state.clock.elapsedTime;
    items.forEach((c, i) => {
      const m = meshes.current[i];
      if (!m) return;
      const spread = 1 + (1 - show) * 0.8;
      const sx = small ? 0.62 : 1;
      // keep right-hand cards inside the screen on narrower windows (0.81 = half a card)
      const maxX = (width / 2 - 0.12 - g.position.x) / g.scale.x - 0.81;
      const x = Math.min(c.pos[0] * spread * sx, maxX);
      m.position.set(x, c.pos[1] * spread + Math.sin(t * 0.9 + i * 1.7) * 0.06, c.pos[2]);
      m.rotation.z = Math.sin(t * 0.6 + i) * 0.03;
      mats.current[i].opacity = damp(mats.current[i].opacity, show, 6, d);
      m.visible = mats.current[i].opacity > 0.01;
    });
  });

  return (
    <group ref={group}>
      {items.map((c, i) => (
        <mesh key={c.title} ref={(el) => (meshes.current[i] = el)} renderOrder={10}>
          <planeGeometry args={[1.62, 0.45]} />
          <meshBasicMaterial ref={(el) => (mats.current[i] = el)} map={c.tex} transparent opacity={0} toneMapped={false} depthWrite={false} depthTest={false} />
        </mesh>
      ))}
    </group>
  );
}

// Slow drifting specks for depth.
function Dust({ count }) {
  const ref = useRef();
  const positions = useMemo(() => {
    const a = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      a[i * 3] = (Math.random() - 0.5) * 16;
      a[i * 3 + 1] = (Math.random() - 0.5) * 10;
      a[i * 3 + 2] = (Math.random() - 0.5) * 6 - 1;
    }
    return a;
  }, [count]);
  useFrame((state, dt) => {
    if (!ref.current) return;
    ref.current.rotation.y += dt * 0.01;
    ref.current.position.y = Math.sin(state.clock.elapsedTime * 0.1) * 0.2;
  });
  return (
    <points ref={ref}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial size={0.025} color="#9fb3cf" transparent opacity={0.45} sizeAttenuation depthWrite={false} />
    </points>
  );
}

function Lights({ quality }) {
  return (
    <>
      <ambientLight intensity={0.35} />
      <directionalLight position={[3, 4, 6]} intensity={1.4} />
      <directionalLight position={[-5, -2, -3]} intensity={0.9} color="#7fa6dc" />
      <Environment resolution={quality === 'high' ? 256 : 64} frames={1}>
        <Lightformer form="rect" intensity={2.4} position={[0, 4, 5]} scale={[10, 1.4, 1]} />
        <Lightformer form="rect" intensity={1.6} position={[-6, 0, 2]} rotation-y={Math.PI / 2} scale={[8, 2, 1]} />
        <Lightformer form="rect" intensity={1.2} color="#e3c79f" position={[6, -1, 0]} rotation-y={-Math.PI / 2} scale={[8, 1.5, 1]} />
        <Lightformer form="ring" intensity={0.6} color="#9fb3cf" position={[0, 0, -8]} scale={5} />
      </Environment>
    </>
  );
}

export default function Scene({ active, small, reduced }) {
  const [dpr, setDpr] = useState(small ? 1.25 : 1.75);
  const quality = small ? 'low' : 'high';

  return (
    <Canvas
      dpr={dpr}
      frameloop={active ? 'always' : 'never'}
      camera={{ position: [0, 0, 10], fov: 30, near: 0.1, far: 50 }}
      gl={{ antialias: !small, alpha: true, powerPreference: 'high-performance' }}
    >
      <PerformanceMonitor onDecline={() => setDpr(1)} />
      <Lights quality={quality} />
      <Suspense fallback={null}>
        <Phone quality={quality} />
        {/* the floating cards crowd a phone-sized hero, so phones skip them */}
        {!small && <Chips small={false} />}
      </Suspense>
      {!reduced && <Dust count={small ? 90 : 260} />}
    </Canvas>
  );
}
