// The bridge between GSAP (which owns scroll) and the 3D scene (which owns
// rendering). GSAP tweens these plain numbers; the scene eases its meshes
// toward them every frame. x / y are fractions of the visible viewport so the
// same choreography works at any screen size.
export const stage = {
  x: 0.2,
  y: -0.02,
  rotX: 0.08,
  rotY: -0.5,
  rotZ: 0.04,
  scale: 1,
  spin: 0, // whole turns added to rotY
  screen: 0, // fractional index into SCREENS; 1.5 = halfway from screen 1 to 2
  chips: 1, // floating UI cards, 0 = hidden
  enter: 0, // 0 -> 1 intro animation
  still: false, // prefers-reduced-motion: no easing, no idle motion
};

// Screens the phone shows, in tour order (public/screens/*.jpg).
export const SCREENS = ['home', 'billing', 'invoices', 'clients', 'attendance', 'payroll', 'reports'];

// Shared pointer, -1..1, written by a window listener (the canvas itself
// ignores pointer events so it never blocks clicks on the page).
export const pointer = { x: 0, y: 0 };

export const isSmallScreen = () => window.matchMedia('(max-width: 900px)').matches;
export const prefersReducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (import.meta.env.DEV) window.__stage = stage; // inspect from the console while developing
