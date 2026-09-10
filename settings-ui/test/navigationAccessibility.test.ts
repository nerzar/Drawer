import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const appSource = readFileSync(new URL('../src/App.vue', import.meta.url), 'utf8')
const sidebarSource = readFileSync(new URL('../src/components/Sidebar.vue', import.meta.url), 'utf8')
const footerSource = readFileSync(new URL('../src/components/FooterBar.vue', import.meta.url), 'utf8')
const aboutSource = readFileSync(new URL('../src/views/AboutView.vue', import.meta.url), 'utf8')
const generalSource = readFileSync(new URL('../src/views/GeneralView.vue', import.meta.url), 'utf8')
const slotsSource = readFileSync(new URL('../src/views/SlotsView.vue', import.meta.url), 'utf8')
const stylesSource = readFileSync(new URL('../src/styles.css', import.meta.url), 'utf8')
const i18nSource = readFileSync(new URL('../src/i18n/index.ts', import.meta.url), 'utf8')

test('G06: App.vue lifts selected slot state to parent and does not use KeepAlive', () => {
  assert.match(appSource, /const selectedSlotNumber = ref\(1\)/)
  assert.match(appSource, /:selected-slot="selectedSlotNumber"/)
  assert.match(appSource, /@update:selected-slot="selectedSlotNumber = \$event"/)
  assert.match(appSource, /if \(target\.tab === 'slots' && target\.slot\)\s*\{\s*selectedSlotNumber\.value = target\.slot/)
  assert.doesNotMatch(appSource, /<KeepAlive>/i)
  assert.doesNotMatch(appSource, /<keep-alive>/i)
})

test('G06: SlotsView defines selectedSlot prop and scrolls selected row into view', () => {
  assert.match(slotsSource, /selectedSlot:\s*\{\s*type:\s*Number,\s*default:\s*1,?\s*\}/)
  assert.match(slotsSource, /defineEmits\(\[['"]update:selectedSlot['"]\]\)/)
  assert.match(slotsSource, /scrollIntoView\(\{\s*block:\s*['"]nearest['"]\s*\}\)/)
  assert.match(slotsSource, /:ref="\(el\)\s*=>\s*setSlotRowRef\(slot\.number,\s*el\)"/)
})

test('G06/localization: Sidebar uses nav semantics, aria-current, and localized labels', () => {
  assert.match(sidebarSource, /<nav class="sidebar" :aria-label="t\('sidebar\.aria'\)">/)
  assert.match(sidebarSource, /:aria-current="active === tab\.key \? 'page' : undefined"/)
  assert.match(sidebarSource, /labelKey:\s*'sidebar\.tab\.general'/)
  assert.match(sidebarSource, /labelKey:\s*'sidebar\.tab\.slots'/)
  assert.match(sidebarSource, /labelKey:\s*'sidebar\.tab\.about'/)
  // Русский остаётся источником по умолчанию, а английский — настоящий перевод, а не копия ключа.
  assert.match(i18nSource, /'sidebar\.tab\.general':\s*\{\s*ru:\s*'Общие',\s*en:\s*'General'\s*\}/)
  assert.match(i18nSource, /'sidebar\.tab\.slots':\s*\{\s*ru:\s*'Слоты',\s*en:\s*'Slots'\s*\}/)
  assert.match(i18nSource, /'sidebar\.tab\.about':\s*\{\s*ru:\s*'О программе',\s*en:\s*'About'\s*\}/)
})

test('G06/localization: About view has truthful configurable/default wording for per-slot shortcut', () => {
  assert.match(
    i18nSource,
    /'about\.hotkey\.toggle':\s*\{\s*ru:\s*'Показать \/ убрать окно — клавиша настраивается для каждого слота; по умолчанию Ctrl \+ Alt \+ N'/,
  )
  assert.doesNotMatch(i18nSource, /Выдвинуть \/ убрать окно слота/)
  assert.match(aboutSource, /desc:\s*t\('about\.hotkey\.toggle'\)/)
})

test('G06/localization: GeneralView binds labels with for/id, adds aria-invalid, and preserves G03 save-lock', () => {
  assert.match(generalSource, /<label for="general-width">\{\{ t\('general\.field\.width'\) \}\}<\/label>/)
  assert.match(generalSource, /id="general-width"/)
  assert.match(generalSource, /:aria-invalid="bad\('general\.dynamicDefaults\.widthPercent'\) \? 'true' : undefined"/)

  assert.match(generalSource, /<label for="general-edge">\{\{ t\('general\.field\.edge'\) \}\}<\/label>/)
  assert.match(generalSource, /id="general-edge"/)

  assert.match(generalSource, /<label for="general-monitor-kind">\{\{ t\('general\.field\.monitor'\) \}\}<\/label>/)
  assert.match(generalSource, /id="general-monitor-kind"/)
  assert.match(generalSource, /:aria-invalid="bad\('general\.dynamicDefaults\.monitor'\) \|\| bad\('general\.dynamicDefaults\.monitor\.number'\) \? 'true' : undefined"/)

  assert.match(generalSource, /<label for="general-accent">\{\{ t\('general\.field\.accent'\) \}\}<\/label>/)
  assert.match(generalSource, /id="general-accent"/)

  assert.match(generalSource, /<label for="general-anim-preset">\{\{ t\('general\.field\.animPreset'\) \}\}<\/label>/)
  assert.match(generalSource, /id="general-anim-preset"/)

  assert.match(generalSource, /<label for="general-blur-ms">\{\{ t\('general\.field\.blurCheckMs'\) \}\}<\/label>/)
  assert.match(generalSource, /id="general-blur-ms"/)
  assert.match(generalSource, /:aria-invalid="bad\('general\.blurCheckMs'\) \? 'true' : undefined"/)

  // Переведённые подписи существуют и на русском не пустые.
  assert.match(i18nSource, /'general\.field\.width':\s*\{\s*ru:\s*'Размер окна'/)
  assert.match(i18nSource, /'general\.field\.edge':\s*\{\s*ru:\s*'Сторона выезда'/)
  assert.match(i18nSource, /'general\.field\.monitor':\s*\{\s*ru:\s*'Монитор'/)
  assert.match(i18nSource, /'general\.field\.blurCheckMs':\s*\{\s*ru:\s*'Проверка потери фокуса \(мс\)'/)

  // G03 save-lock preserved
  assert.match(generalSource, /const saving = computed\(\(\) => settings\.status === 'saving'\)/)
  assert.match(generalSource, /<fieldset v-else class="editor grid2" :disabled="saving">/)
})

test('G06: FooterBar status and discard confirmation semantics', () => {
  assert.match(footerSource, /role="status"/)
  assert.match(footerSource, /aria-live="polite"/)
  assert.match(footerSource, /aria-atomic="true"/)
  assert.match(footerSource, /role="alert"/)
  assert.match(footerSource, /aria-live="assertive"/)
  assert.match(footerSource, /keepButtonRef\.value\?\.focus\(\)/)
})

test('G06/localization: SlotsView accessible names for pickers, help description, and aria-invalid', () => {
  assert.match(slotsSource, /:aria-label="t\('slots\.pickExe\.aria'\)"/)
  assert.match(slotsSource, /:aria-label="t\('slots\.pickWindow\.aria'\)"/)
  assert.match(slotsSource, /aria-describedby="slot-class-tip"/)
  assert.match(slotsSource, /id="slot-class-tip"/)
  assert.match(slotsSource, /role="note"/)
  assert.match(slotsSource, /:aria-label="t\('slots\.classTip\.aria'\)"/)
  assert.match(slotsSource, /:aria-invalid="bad\('name'\) \? 'true' : undefined"/)
  assert.match(slotsSource, /:aria-invalid="bad\('executable'\) \? 'true' : undefined"/)
  assert.match(slotsSource, /:aria-invalid="bad\('monitor'\) \|\| bad\('monitor\.number'\) \? 'true' : undefined"/)
  assert.match(slotsSource, /:aria-invalid="bad\('widthPercent'\) \? 'true' : undefined"/)
  assert.match(slotsSource, /:aria-invalid="bad\('hotkey'\) \? 'true' : undefined"/)

  assert.match(i18nSource, /'slots\.pickExe\.aria':\s*\{\s*ru:\s*'Выбрать приложение для слота'/)
  assert.match(i18nSource, /'slots\.pickWindow\.aria':\s*\{\s*ru:\s*'Взять данные из открытого окна для слота'/)
  assert.match(i18nSource, /'slots\.classTip\.aria':\s*\{\s*ru:\s*'Справка о признаке окна'/)
})

test('G06: CSS rules for contrast, focus-visible, scrollbars, and disabled opacity', () => {
  // Contrast improvement for --text-3
  assert.match(stylesSource, /--text-3:\s*#8c8e96;/)

  // Focus-visible treatment
  assert.match(stylesSource, /:focus-visible\s*\{[\s\S]*?outline:\s*2px solid var\(--accent-fg\);/)

  // Явный резерв под скроллбар убран — он давал лишний отступ, даже когда
  // список слотов не скроллится.
  assert.doesNotMatch(slotsSource, /scrollbar-gutter/)

  // Avoid compounded fieldset disabled opacity
  assert.match(slotsSource, /button\[disabled\],\s*input\[disabled\],\s*select\[disabled\]\s*\{\s*opacity:\s*0\.5;\s*\}/)
  assert.doesNotMatch(slotsSource, /fieldset\[disabled\]\s*\{[\s\S]*?opacity:/)
})
