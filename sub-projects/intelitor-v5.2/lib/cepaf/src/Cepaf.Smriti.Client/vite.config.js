import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  root: '.',
  base: '/',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: true
  },
  server: {
    port: 3001,
    open: true,
    proxy: {
      // Proxy API requests to the Giraffe backend
      '/api': {
        target: 'http://localhost:5000',
        changeOrigin: true
      },
      '/mcp': {
        target: 'http://localhost:5000',
        changeOrigin: true
      }
    }
  },
  resolve: {
    alias: {
      // Fable generates .fs.js files
    }
  }
})
