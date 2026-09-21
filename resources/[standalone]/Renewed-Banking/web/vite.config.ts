import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
import path from "node:path"
import tailwindcss from "@tailwindcss/postcss"
import autoprefixer from "autoprefixer"

export default defineConfig({
  plugins: [react()],
  base: "./",
  // `web/public` é o que o fxmanifest do Renewed-Banking já serve. Escrevendo direto ali, o
  // manifesto dele não precisa de uma linha de alteração -- a interface é um drop-in.
  //
  // `publicDir: false` desliga o significado especial que o Vite dá à pasta `public`; sem isso
  // ele tentaria copiá-la para dentro de si mesma. As fontes moraram para `src/fonts` por causa
  // disso, e saem como assets normais.
  publicDir: false,
  build: {
    outDir: "public",
    emptyOutDir: true,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes("node_modules")) {
            if (id.includes("react")) return "react"
            return "vendor"
          }
        },
      },
    },
  },
  css: { postcss: { plugins: [tailwindcss(), autoprefixer()] } },
  resolve: { alias: { "@": path.resolve(__dirname, "./src") } },
})
