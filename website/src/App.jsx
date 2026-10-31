import { lazy, Suspense, useEffect, useRef, useState, useSyncExternalStore } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { ScrollSmoother } from 'gsap/ScrollSmoother';
import { SplitText } from 'gsap/SplitText';
import { useGSAP } from '@gsap/react';
import { Menu, X } from 'lucide-react';
import WhatsAppIcon from './WhatsAppIcon';
import { stage, pointer } from './three/stage';
import { whatsappLink } from './config';
import { Hero, Marquee, Tour, Features, WhatsApp, FollowUp, Gallery, Security, Platforms, GetStarted, Faq, Contact, Footer } from './Sections';
import Legal from './Legal.jsx';

gsap.registerPlugin(ScrollTrigger, ScrollSmoother, SplitText, useGSAP);

// three.js is the heaviest part of the page; load it after the first paint.
const Scene = lazy(() => import('./three/Scene'));

function useMedia(query) {
  return useSyncExternalStore(
    (cb) => {
      const m = window.matchMedia(query);
      m.addEventListener('change', cb);
      return () => m.removeEventListener('change', cb);
    },
    () => window.matchMedia(query).matches,
  );
}

function useHashRoute() {
  const read = () => {
    const h = window.location.hash;
    if (h === '#/privacy') return 'privacy';
    if (h === '#/disclaimer') return 'disclaimer';
    return 'home';
  };
  const [route, setRoute] = useState(read);
  useEffect(() => {
    const on = () => setRoute(read());
    window.addEventListener('hashchange', on);
    return () => window.removeEventListener('hashchange', on);
  }, []);
  return route;
}

// Scroll to a section, through ScrollSmoother when it is running.
function scrollToId(id) {
  const el = document.getElementById(id);
  if (!el) return;
  const smoother = ScrollSmoother.get();
  if (smoother) smoother.scrollTo(el, true, 'top top');
  else el.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
}

const NAV = [
  ['tour', 'App tour'],
  ['features', 'Features'],
  ['whatsapp', 'WhatsApp'],
  ['security', 'Security'],
  ['pricing', 'Pricing'],
  ['faq', 'FAQ'],
];

function Nav({ forceLight }) {
  const [scrolled, setScrolled] = useState(false);
  const [light, setLight] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 30);
    on();
    window.addEventListener('scroll', on, { passive: true });
    return () => window.removeEventListener('scroll', on);
  }, []);

  // Dark text over the light panels, white over the navy ones.
  useEffect(() => {
    if (forceLight) return;
    let active = 0;
    const triggers = gsap.utils.toArray('[data-nav="light"]').map((el) =>
      ScrollTrigger.create({
        trigger: el,
        start: 'top 34px',
        end: 'bottom 34px',
        onToggle: (self) => {
          active += self.isActive ? 1 : -1;
          setLight(active > 0);
        },
      }),
    );
    return () => triggers.forEach((t) => t.kill());
  }, [forceLight]);

  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : '';
  }, [open]);

  const go = (e, id) => {
    e.preventDefault();
    setOpen(false);
    if (forceLight) {
      window.location.hash = '';
      setTimeout(() => scrollToId(id), 60);
    } else scrollToId(id);
  };

  return (
    <>
      <header className={`nav ${scrolled || forceLight ? 'scrolled' : ''} ${light || forceLight ? 'light' : ''}`}>
        <div className="wrap nav-inner">
          <a className="brand" href="#top" onClick={(e) => go(e, 'top')} aria-label="Stylux home">
            <img src="/brand/stylux-192.png" alt="" width="32" height="32" /> STYLUX
          </a>
          <nav className="nav-links" aria-label="Main">
            {NAV.map(([id, label]) => (
              <a key={id} href={`#${id}`} onClick={(e) => go(e, id)}>
                {label}
              </a>
            ))}
          </nav>
          <a className="btn btn-primary btn-sm nav-cta" href="#contact" onClick={(e) => go(e, 'contact')}>
            Contact us
          </a>
          <button className="menu-btn" aria-label="Open menu" aria-expanded={open} onClick={() => setOpen(true)}>
            <Menu size={24} />
          </button>
        </div>
      </header>
      {open && (
        <div className="drawer" role="dialog" aria-modal="true" aria-label="Menu">
          <div className="drawer-top">
            <span className="brand">
              <img src="/brand/stylux-192.png" alt="" width="32" height="32" /> STYLUX
            </span>
            <button className="menu-btn" style={{ display: 'inline-flex' }} aria-label="Close menu" onClick={() => setOpen(false)}>
              <X size={26} />
            </button>
          </div>
          <nav>
            {[...NAV, ['contact', 'Contact']].map(([id, label]) => (
              <a key={id} href={`#${id}`} onClick={(e) => go(e, id)}>
                {label}
              </a>
            ))}
          </nav>
          <a className="btn btn-wa" href={whatsappLink()} target="_blank" rel="noopener" style={{ marginTop: 32 }}>
            <WhatsAppIcon size={18} /> WhatsApp us
          </a>
        </div>
      )}
    </>
  );
}

function Home() {
  const small = useMedia('(max-width: 900px)');
  const reduced = useMedia('(prefers-reduced-motion: reduce)');
  const [canvasOn, setCanvasOn] = useState(true);
  const [fontsReady, setFontsReady] = useState(false);
  const root = useRef();

  useEffect(() => {
    document.title = 'Stylux - Salon management app for billing, clients, staff and WhatsApp';
  }, []);

  useEffect(() => {
    let alive = true;
    Promise.all([
      document.fonts.load('700 44px "Plus Jakarta Sans"'),
      document.fonts.load('500 34px "Plus Jakarta Sans"'),
    ])
      .catch(() => {})
      .then(() => alive && setFontsReady(true));
    return () => {
      alive = false;
    };
  }, []);

  useEffect(() => {
    if (small || reduced) return;
    const on = (e) => {
      pointer.x = (e.clientX / window.innerWidth) * 2 - 1;
      pointer.y = (e.clientY / window.innerHeight) * 2 - 1;
    };
    window.addEventListener('pointermove', on, { passive: true });
    return () => window.removeEventListener('pointermove', on);
  }, [small, reduced]);

  // In-page links marked data-scroll go through the smoother.
  useEffect(() => {
    const on = (e) => {
      const a = e.target.closest('a[data-scroll]');
      if (!a) return;
      e.preventDefault();
      scrollToId(a.dataset.scroll);
    };
    document.addEventListener('click', on);
    return () => document.removeEventListener('click', on);
  }, []);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();

      mm.add(
        { desktop: '(min-width: 901px)', mobile: '(max-width: 900px)', reduce: '(prefers-reduced-motion: reduce)' },
        (ctx) => {
          const { desktop, reduce } = ctx.conditions;

          // ---- hero pose ----
          const heroPose = desktop
            ? { x: window.innerWidth < 1200 ? 0.27 : 0.25, y: -0.02, rotX: 0.08, rotY: -0.5, rotZ: 0.05, scale: 0.96 }
            : { x: 0, y: -0.27, rotX: 0.12, rotY: -0.38, rotZ: 0.04, scale: 0.64 };
          const tourPose = desktop
            ? { x: 0.22, y: 0, rotX: 0.02, rotY: -0.2, rotZ: 0, scale: 1.02 }
            : { x: 0, y: 0.15, rotX: 0.03, rotY: -0.15, rotZ: 0, scale: 0.8 };
          Object.assign(stage, heroPose, { screen: 0, chips: 1, spin: 0 });

          if (reduce) {
            stage.still = true;
            stage.enter = 1;
            // no tour animation: the phone stays in the hero, so stop drawing it once the tour covers it
            ScrollTrigger.create({ trigger: '#tour', start: 'top top', onEnter: () => setCanvasOn(false), onLeaveBack: () => setCanvasOn(true) });
            return () => {
              stage.still = false;
            };
          }
          stage.still = false;

          // Smooth scrolling only with a mouse/trackpad. On touch phones the browser's own
          // scrolling is used: iOS Safari's collapsing toolbars and momentum fight a
          // transformed scroller.
          const smoother = window.matchMedia('(pointer: fine)').matches
            ? ScrollSmoother.create({ wrapper: '#smooth-wrapper', content: '#smooth-content', smooth: 1.1, effects: true })
            : null;

          // ---- intro ----
          stage.enter = 0;
          gsap.to(stage, { enter: 1, duration: 2, ease: 'power3.out', delay: 0.15 });
          // autoSplit re-splits once the web fonts arrive (and on resize), so lines break where they really do
          const title = SplitText.create('.hero-title', {
            type: 'lines,words',
            mask: 'lines',
            autoSplit: true,
            onSplit: (self) => gsap.from(self.lines, { yPercent: 110, duration: 1.1, ease: 'power4.out', stagger: 0.09, delay: 0.1 }),
          });
          gsap.from('.hero-in', { y: 24, autoAlpha: 0, duration: 0.9, ease: 'power3.out', stagger: 0.08, delay: 0.45 });

          // ---- hero -> tour: phone settles in front of the tour copy ----
          // The phone's pose is worked out in one place (compose, below) from how far
          // each section has scrolled. Scroll triggers only report their own progress,
          // so no two tweens ever fight over the same value, whatever order you scroll in.
          let heroST = null;
          let leaveST = null;
          const tourScreen = { value: 0 };
          const wobble = (i) => (i === 0 ? tourPose.rotY : i % 2 ? -0.34 : -0.12);
          const lerp = gsap.utils.interpolate;
          const compose = () => {
            const h = heroST ? heroST.progress : 0;
            const sc = tourScreen.value;
            const i = Math.floor(sc);
            const f = sc - i;
            const l = gsap.parseEase('power1.in')(leaveST ? leaveST.progress : 0);
            stage.x = lerp(heroPose.x, tourPose.x, h);
            stage.rotX = lerp(heroPose.rotX, tourPose.rotX, h);
            stage.rotZ = lerp(heroPose.rotZ, tourPose.rotZ, h) + (sc > 0 ? Math.sin(sc * Math.PI) * 0.02 : 0);
            stage.rotY = lerp(heroPose.rotY, lerp(wobble(i), wobble(i + 1), f), h);
            stage.y = lerp(lerp(heroPose.y, tourPose.y, h), desktop ? 0.45 : 0.5, l);
            stage.scale = lerp(lerp(heroPose.scale, tourPose.scale, h), 0.75, l);
            stage.spin = 0.25 * l;
            stage.chips = 1 - h;
            stage.screen = sc;
          };
          gsap.ticker.add(compose);

          heroST = gsap
            .timeline({ scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom top', scrub: true } })
            .to('.hero-copy', { y: -80, autoAlpha: 0, ease: 'none' }, 0)
            .to('.scroll-hint', { autoAlpha: 0, ease: 'none', duration: 0.2 }, 0).scrollTrigger;

          gsap.to('.marquee-track', { xPercent: -50, ease: 'none', duration: 40, repeat: -1 });

          // ---- pinned tour: one step per screen ----
          const steps = gsap.utils.toArray('.tour-step');
          const bars = gsap.utils.toArray('.tour-progress b');
          const tour = gsap.timeline({
            defaults: { ease: 'power2.inOut' },
            scrollTrigger: {
              trigger: '.tour',
              start: 'top top',
              end: () => `+=${window.innerHeight * (steps.length - 0.4)}`,
              pin: true,
              scrub: 0.6,
              anticipatePin: 1,
            },
          });
          gsap.set(bars[0], { scaleX: 1 });
          for (let i = 1; i < steps.length; i++) {
            const at = i * 1.4 - 0.6;
            tour
              .to(steps[i - 1], { autoAlpha: 0, y: -40, duration: 0.45 }, at)
              .to(tourScreen, { value: i, duration: 1 }, at)
              .fromTo(steps[i], { autoAlpha: 0, y: 40 }, { autoAlpha: 1, y: 0, duration: 0.5 }, at + 0.45)
              .fromTo(steps[i].querySelectorAll('li'), { autoAlpha: 0, x: -16 }, { autoAlpha: 1, x: 0, stagger: 0.06, duration: 0.3 }, at + 0.6)
              .to(bars[i], { scaleX: 1, duration: 0.5 }, at + 0.3);
          }
          tour.to({}, { duration: 0.5 }); // hold on the last screen
          gsap.from(steps[0].children, { y: 30, autoAlpha: 0, stagger: 0.08, duration: 0.8, ease: 'power3.out', scrollTrigger: { trigger: '.tour', start: 'top 65%' } });
          // the floating WhatsApp button would cover the tour captions on phones
          ScrollTrigger.create({ trigger: '.tour', start: 'top 80%', end: () => `+=${window.innerHeight * (steps.length + 0.4)}`, toggleClass: { targets: document.body, className: 'in-tour' } });

          // ---- leaving the tour: phone drifts up and away under the first panel ----
          leaveST = ScrollTrigger.create({ trigger: '#features', start: 'top bottom', end: 'top top' });
          // Stop rendering once the 3D stage is fully covered.
          ScrollTrigger.create({
            trigger: '#features',
            start: 'top top',
            onEnter: () => setCanvasOn(false),
            onLeaveBack: () => setCanvasOn(true),
          });

          return () => {
            gsap.ticker.remove(compose);
            title.revert();
            smoother?.kill();
          };
        },
      );

      // ---- reveals shared by every layout (skipped for reduced motion) ----
      mm.add('(prefers-reduced-motion: no-preference)', () => {
        gsap.utils.toArray('h2.split').forEach((h) => {
          SplitText.create(h, {
            type: 'lines',
            mask: 'lines',
            autoSplit: true,
            onSplit: (self) =>
              gsap.from(self.lines, {
                yPercent: 105,
                duration: 1,
                ease: 'power4.out',
                stagger: 0.08,
                scrollTrigger: { trigger: h, start: 'top 85%' },
              }),
          });
        });
        gsap.set('.reveal-card', { autoAlpha: 0, y: 48 });
        ScrollTrigger.batch('.reveal-card', {
          start: 'top 90%',
          onEnter: (els) => gsap.to(els, { autoAlpha: 1, y: 0, duration: 0.9, ease: 'power3.out', stagger: 0.07, overwrite: true }),
        });
        gsap.set('.reveal-up', { autoAlpha: 0, y: 28 });
        ScrollTrigger.batch('.reveal-up', {
          start: 'top 90%',
          onEnter: (els) => gsap.to(els, { autoAlpha: 1, y: 0, duration: 0.8, ease: 'power3.out', stagger: 0.1, overwrite: true }),
        });

        // WhatsApp bubbles arrive one after another
        gsap.from('.chat .bubble', {
          y: 26,
          scale: 0.94,
          autoAlpha: 0,
          transformOrigin: 'left top',
          duration: 0.6,
          ease: 'back.out(1.6)',
          stagger: 0.55,
          scrollTrigger: { trigger: '.chat', start: 'top 70%' },
        });
        gsap.from('.chat', {
          rotateY: -18,
          rotateX: 6,
          transformPerspective: 1200,
          ease: 'none',
          scrollTrigger: { trigger: '.chat', start: 'top bottom', end: 'center center', scrub: true },
        });

        // Security: salons drop into their own separate vaults
        gsap.from('.vault', {
          rotateX: 70,
          y: 60,
          autoAlpha: 0,
          transformOrigin: '50% 100%',
          stagger: { each: 0.08, from: 'start' },
          duration: 0.9,
          ease: 'power3.out',
          scrollTrigger: { trigger: '.vaults', start: 'top 80%' },
        });
        gsap.to('.vault:first-child', {
          y: -10,
          boxShadow: '0 30px 60px -20px rgba(30,58,95,0.45)',
          borderColor: '#1e3a5f',
          scrollTrigger: { trigger: '.vaults', start: 'top 55%', end: 'bottom 40%', scrub: true },
        });

        gsap.from('.big-word', { yPercent: 40, autoAlpha: 0, ease: 'none', scrollTrigger: { trigger: '.footer', start: 'top bottom', end: 'bottom bottom', scrub: true } });
      });

      // Gallery: horizontal scroll on desktop, native swipe on phones.
      mm.add('(min-width: 901px) and (prefers-reduced-motion: no-preference)', () => {
        const track = document.querySelector('.gallery-track');
        const distance = () => Math.max(0, track.scrollWidth - window.innerWidth + 80);
        gsap.to(track, {
          x: () => -distance(),
          ease: 'none',
          scrollTrigger: {
            trigger: '.gallery-pin',
            start: 'top top',
            end: () => `+=${distance()}`,
            pin: true,
            scrub: 0.8,
            invalidateOnRefresh: true,
          },
        });
        gsap.utils.toArray('.shot').forEach((el, i) => {
          gsap.fromTo(el, { y: i % 2 ? 14 : -14 }, { y: i % 2 ? -14 : 14, ease: 'none', scrollTrigger: { trigger: '.gallery-pin', start: 'top top', end: () => `+=${distance()}`, scrub: true } });
        });
      });

      return () => mm.revert();
    },
    { scope: root, dependencies: [] },
  );

  // Fonts and images change layout; recalculate trigger positions once they land.
  useEffect(() => {
    const t = setTimeout(() => ScrollTrigger.refresh(), 600);
    window.addEventListener('load', () => ScrollTrigger.refresh(), { once: true });
    return () => clearTimeout(t);
  }, []);

  return (
    <div ref={root}>
      <div className="backdrop" aria-hidden="true" />
      <div className="stage" aria-hidden="true">
        {fontsReady && (
          <Suspense fallback={null}>
            <Scene active={canvasOn} small={small} reduced={reduced} />
          </Suspense>
        )}
      </div>
      <Nav />
      <div id="smooth-wrapper">
        <div id="smooth-content">
          <main id="main">
            <Hero />
            <Marquee />
            <Tour reduced={reduced} />
            <Features />
            <WhatsApp />
            <FollowUp />
            <Gallery />
            <Security />
            <Platforms />
            <GetStarted />
            <Faq />
            <Contact />
          </main>
          <Footer />
        </div>
      </div>
      <a className="fab" href={whatsappLink()} target="_blank" rel="noopener" aria-label="Chat with us on WhatsApp">
        <WhatsAppIcon size={28} />
      </a>
    </div>
  );
}

export default function App() {
  const route = useHashRoute();
  return (
    <>
      <a className="skip" href="#main">
        Skip to content
      </a>
      {route === 'home' ? (
        <Home />
      ) : (
        <>
          <Nav forceLight />
          <Legal kind={route} />
        </>
      )}
    </>
  );
}

