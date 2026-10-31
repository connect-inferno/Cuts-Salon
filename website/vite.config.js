import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    // three.js lives in its own lazy-loaded chunk (src/three/Scene.jsx), loaded
    // after the page has painted, so its size doesn't block first render.
    chunkSizeWarningLimit: 1100,
  },
})
