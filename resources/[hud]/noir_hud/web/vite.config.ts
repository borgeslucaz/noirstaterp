import { defineConfig, type PluginOption } from "vite";
import preact from "@preact/preset-vite";
import path from "path";
import { visualizer } from "rollup-plugin-visualizer";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [preact(), visualizer() as PluginOption],
  base: "./",
  build: {
    outDir: "../dist",
    emptyOutDir: true,
    minify: "terser",
    sourcemap: false,
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true,
        pure_funcs: [
          "console.log",
          "console.info",
          "console.debug",
          "console.trace",
        ],
        passes: 2,
        ecma: 2020,
      },
      format: {
        comments: false,
        ecma: 2020,
      },
      mangle: {
        properties: {
          regex: /^_/,
        },
      },
    },
    rollupOptions: {
      output: {
        // Stable names keep the FXServer resource catalogue valid between builds.
        entryFileNames: "assets/[name].js",
        chunkFileNames: "assets/[name].js",
        assetFileNames: "assets/[name].[ext]",
      },
    },
    target: ["es2020", "edge88", "firefox78", "chrome87", "safari14"],
    cssCodeSplit: true,
    assetsInlineLimit: 4096,
    chunkSizeWarningLimit: 1000,
    reportCompressedSize: true,
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "~": path.resolve(__dirname, "./"),
      $lib: path.resolve("./src/lib"),
    },
  },
});
