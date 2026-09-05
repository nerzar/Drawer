import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Сборка кладётся туда, откуда её берёт хост, — src/webview/web рядом с
// drawer.ahk. Папка отображается WebView2 на виртуальный хост, поэтому
// пути в index.html должны быть относительными: абсолютный /assets/…
// на виртуальном хосте указывал бы в корень хоста, а не сборки.
export default defineConfig({
  base: './',
  plugins: [vue()],
  build: {
    outDir: '../src/webview/web',
    emptyOutDir: true,
  },
})
