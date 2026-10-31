# Stylux website

Marketing site for the Stylux salon app. React (Vite), three.js via
react-three-fiber, and GSAP (ScrollTrigger, ScrollSmoother, SplitText).
Separate from the app in `mobile/`; nothing here talks to Firebase.

```bash
npm install
npm run dev      # http://localhost:5190 via .claude/launch.json "website"
npm run build    # static files in dist/
```

## Hosting

Live at https://stylux.infernos.co.in (custom domain) and
https://salon-saas-87b6a.web.app - Firebase Hosting in the shared
`salon-saas-87b6a` project; `firebase.json` / `.firebaserc` here are
hosting-only).

```bash
npm run build
firebase deploy --only hosting --project salon-saas-87b6a
```

Keep `--only hosting`: that project's Firestore rules, Storage and Functions
are deployed from other folders, and a bare deploy from here must never touch
them. `index.html` is served `no-cache`; hashed files in `assets/` are cached
for a year.

## Where things live

- `src/config.js` - WhatsApp number, phone, email, the Infernos link.
- `src/content.js` - tour steps, feature cards, gallery captions, FAQ. Only
  claim what the app really does (check CLAUDE.md).
- `src/legalText.js` - privacy policy and disclaimer, generated from
  `mobile/lib/features/legal/legal_pages.dart`. Update both together.
- `src/three/Scene.jsx` - the 3D phone, floating cards and lighting.
  `src/three/stage.js` holds the numbers GSAP animates and the scene follows.
- `src/App.jsx` - page layout and all scroll choreography (`useGSAP`).
- `public/screens/` - app screenshots from the **test** salon
  (`test-salon-ee06a`) at 540 x 873. Phone numbers in `clients.jpg` were
  replaced with dummy 98765... numbers. Retake from the test salon only.

## Performance and accessibility

- three.js loads in its own chunk after first paint; rendering stops once the
  light sections cover the 3D stage.
- Phones (< 900px): lower pixel ratio, no antialiasing, no floating cards,
  fewer particles, native touch scrolling.
- `prefers-reduced-motion`: no smooth scrolling, pinning or reveals; the tour
  becomes a plain list of screenshots and the phone stays still.
