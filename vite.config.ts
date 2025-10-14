import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

import { fileURLToPath, URL } from 'node:url'
export default defineConfig({
resolve: {
  alias: {
    '@': fileURLToPath(new URL('./app/frontend', import.meta.url)),
  },
},
server: { hmr: { overlay: true } },
  plugins: [
    react(),
    tailwindcss(),
    RubyPlugin(),
  ],
})
