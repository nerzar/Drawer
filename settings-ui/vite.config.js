import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { viteSingleFile } from 'vite-plugin-singlefile'

// Сборка кладётся туда, откуда её берёт хост, — src/webview/web рядом с
// drawer.ahk, и представляет собой ОДИН index.html со встроенными JS и
// CSS.
//
// Однофайловость здесь не косметика, а условие упаковки: релизный exe
// вшивает ассеты через FileInstall, а он принимает только литеральное
// имя файла. Обычная сборка Vite даёт assets/index-<hash>.js, и хеш
// меняется на каждой сборке — такой список именами не зафиксировать.
// Один известный файл фиксируется навсегда.
//
// base:'./' остаётся: страницу отдаёт виртуальный хост WebView2, и
// абсолютный /assets/… указывал бы в корень хоста, а не сборки.
export default defineConfig({
  base: './',
  plugins: [vue(), viteSingleFile()],
  build: {
    outDir: '../src/webview/web',
    emptyOutDir: true,
    assetsInlineLimit: 100000000,
    cssCodeSplit: false,
  },
})
