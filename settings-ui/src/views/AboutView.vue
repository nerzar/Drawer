<script setup>
import AppLogo from '../components/AppLogo.vue'

const hotkeys = [
  { combo: ['Ctrl', 'Alt', '1–9'], desc: 'Выдвинуть / убрать окно слота' },
  { combo: ['Ctrl', 'Alt', 'Shift', '1–9'], desc: 'Назначить активное окно слоту' },
  { combo: ['Ctrl', 'Alt', '0'], desc: 'Очистить динамические слоты' },
  { combo: ['Ctrl', 'Alt', 'Shift', '0'], desc: 'Выход, окна возвращаются на места' },
]
</script>

<template>
  <div class="content">
    <div class="about-head">
      <AppLogo :size="52" />
      <div>
        <h1 class="about-title">Drawer <span class="version-pill">0.1.2-beta</span></h1>
      </div>
    </div>

    <h3 class="section">Файл конфигурации</h3>
    <p class="about-p">
      Настройки сохраняются в файле <code>config.ini</code> в папке с программой.
      Программа трогает этот файл только тогда, когда вы нажали «Применить» или «ОК», и записывает
      ровно те строки, которые вы изменили. Ни закрытие окна, ни выход из программы ничего не
      сохраняют.
    </p>

    <div class="link-row">
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--accent-fg)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
        <path d="M14 3h7v7" />
        <path d="M10 14 21 3" />
        <path d="M21 14v5a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h5" />
      </svg>
      <a href="https://github.com/nerzar/Drawer" target="_blank" rel="noopener noreferrer">github.com/nerzar/Drawer</a>
      <span class="muted">· лицензия MIT</span>
    </div>

    <h3 class="section">Горячие клавиши</h3>
    <div>
      <div class="kbd-row" v-for="(hk, i) in hotkeys" :key="i">
        <div class="kbd-combo">
          <template v-for="(key, ki) in hk.combo" :key="ki">
            <span class="kbd">{{ key }}</span>
            <span v-if="ki < hk.combo.length - 1" class="kbd-plus">+</span>
          </template>
        </div>
        <div class="kbd-desc">{{ hk.desc }}</div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.content {
  flex: 1;
  overflow-y: auto;
  padding: 34px 40px;
  max-width: 620px;
}
.about-head {
  display: flex;
  align-items: center;
  gap: 18px;
  margin-bottom: 28px;
}
.about-title {
  font-size: 24px;
  font-weight: 700;
  margin: 0;
  display: flex;
  align-items: center;
  gap: 10px;
}
.version-pill {
  font-size: 11px;
  font-weight: 600;
  color: var(--accent-fg);
  background: var(--accent-tint);
  padding: 3px 9px;
  border-radius: 999px;
}
h3.section {
  font-size: 12.5px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--text-2);
  margin: 0 0 10px;
}
.about-p {
  font-size: 12.5px;
  color: var(--text-2);
  line-height: 1.65;
  margin: 0 0 22px;
}
.about-p code {
  font-family: 'Cascadia Code', Consolas, monospace;
  font-size: 11.5px;
  background: rgba(255, 255, 255, 0.06);
  padding: 2px 6px;
  border-radius: 4px;
  color: var(--text);
}
.link-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  margin-bottom: 30px;
}
.link-row .muted {
  color: var(--text-3);
}
.kbd {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 26px;
  height: 24px;
  padding: 0 7px;
  border-radius: 5px;
  border: 1px solid var(--border-strong);
  background: linear-gradient(#2b2d33, #222329);
  box-shadow: 0 1px 0 rgba(0, 0, 0, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.05);
  font-family: 'Cascadia Code', Consolas, monospace;
  font-size: 11.5px;
  font-weight: 600;
  color: var(--text);
}
.kbd-row {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 9px 0;
  border-bottom: 1px solid var(--border);
}
.kbd-row:last-child {
  border-bottom: none;
}
.kbd-combo {
  display: flex;
  align-items: center;
  gap: 5px;
  flex: 0 0 250px;
}
.kbd-plus {
  color: var(--text-3);
  font-size: 11px;
}
.kbd-desc {
  font-size: 12.5px;
  color: var(--text-2);
}
</style>
