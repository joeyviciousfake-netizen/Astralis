import { defineConfig } from "vite";
import { sveltekit } from "@sveltejs/kit/vite";
import tailwindcss from "@tailwindcss/vite";

// @ts-expect-error process is a nodejs global
const host = process.env.TAURI_DEV_HOST;

export default defineConfig(async () => ({
  plugins: [tailwindcss(), sveltekit()],
  clearScreen: false,
  // vitest: força build client do svelte (sem isso mount() resolve o index-server.js)
  // @ts-expect-error process is a nodejs global
  resolve: process.env.VITEST ? { conditions: ["browser"] } : {},
  server: {
    port: 1420,
    strictPort: true,
    host: host || false,
    hmr: host
      ? {
          protocol: "ws",
          host,
          port: 1421,
        }
      : undefined,
    watch: {
      // projects/ recebe ~722 writes + fusions.json de ~2,3 MB a cada Importar
      // pack: sem ignorar, o Vite entende como mudança de fonte e dá full
      // reload no WebView — e o onMount do +page chamava preparar_boot de
      // novo (antes da flag 1x por processo, isso apagava o importado e a
      // tela "abria zerada"). Dado de trabalho não é fonte: nunca observa.
      ignored: ["**/src-tauri/**", "**/projects/**"],
    },
  },
  test: {
    include: ["src/**/*.{test,spec}.{js,ts}"],
    environment: "jsdom",
    globals: true,
    server: { deps: { inline: [/^svelte/, /@testing-library\/svelte/] } },
  },
}));
