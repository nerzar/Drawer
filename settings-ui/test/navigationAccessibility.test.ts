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

test('G06: Sidebar uses nav semantics, aria-current, and Russian labels', () => {
  assert.match(sidebarSource, /<nav class="sidebar" aria-label="Разделы настроек">/)
  assert.match(sidebarSource, /:aria-current="active === tab\.key \? 'page' : undefined"/)
  assert.match(sidebarSource, /label:\s*'Общие'/)
  assert.match(sidebarSource, /label:\s*'Слоты'/)
  assert.match(sidebarSource, /label:\s*'О программе'/)
  assert.doesNotMatch(sidebarSource, /label:\s*'General'/)
  assert.doesNotMatch(sidebarSource, /label:\s*'Slots'/)
  assert.doesNotMatch(sidebarSource, /label:\s*'About'/)
})

test('G06: About view has truthful configurable/default wording for per-slot shortcut', () => {
  assert.match(
    aboutSource,
    /Показать \/ убрать окно — клавиша настраивается для каждого слота; по умолчанию Ctrl \+ Alt \+ N/,
  )
  assert.doesNotMatch(aboutSource, /Выдвинуть \/ убрать окно слота/)
})

test('G06: GeneralView binds labels with for/id, adds aria-invalid, and preserves G03 save-lock', () => {
  assert.match(generalSource, /<label for="general-width">Размер окна<\/label>/)
  assert.match(generalSource, /id="general-width"/)
  assert.match(generalSource, /:aria-invalid="bad\('general\.dynamicDefaults\.widthPercent'\) \? 'true' : undefined"/)

  assert.match(generalSource, /<label for="general-edge">Сторона выезда<\/label>/)
  assert.match(generalSource, /id="general-edge"/)

  assert.match(generalSource, /<label for="general-monitor-kind">Монитор<\/label>/)
  assert.match(generalSource, /id="general-monitor-kind"/)
  assert.match(generalSource, /:aria-invalid="bad\('general\.dynamicDefaults\.monitor'\) \|\| bad\('general\.dynamicDefaults\.monitor\.number'\) \? 'true' : undefined"/)

  assert.match(generalSource, /<label for="general-accent">Цвет акцента<\/label>/)
  assert.match(generalSource, /id="general-accent"/)

  assert.match(generalSource, /<label for="general-anim-preset">Плавность<\/label>/)
  assert.match(generalSource, /id="general-anim-preset"/)

  assert.match(generalSource, /<label for="general-blur-ms">Проверка потери фокуса \(мс\)<\/label>/)
  assert.match(generalSource, /id="general-blur-ms"/)
  assert.match(generalSource, /:aria-invalid="bad\('general\.blurCheckMs'\) \? 'true' : undefined"/)

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

test('G06: SlotsView accessible names for pickers, help description, and aria-invalid', () => {
  assert.match(slotsSource, /aria-label="Выбрать приложение для слота"/)
  assert.match(slotsSource, /aria-label="Взять данные из открытого окна для слота"/)
  assert.match(slotsSource, /aria-describedby="slot-class-tip"/)
  assert.match(slotsSource, /id="slot-class-tip"/)
  assert.match(slotsSource, /role="note"/)
  assert.match(slotsSource, /aria-label="Справка о признаке окна"/)
  assert.match(slotsSource, /:aria-invalid="bad\('name'\) \? 'true' : undefined"/)
  assert.match(slotsSource, /:aria-invalid="bad\('executable'\) \? 'true' : undefined"/)
  assert.match(slotsSource, /:aria-invalid="bad\('monitor'\) \|\| bad\('monitor\.number'\) \? 'true' : undefined"/)
  assert.match(slotsSource, /:aria-invalid="bad\('widthPercent'\) \? 'true' : undefined"/)
  assert.match(slotsSource, /:aria-invalid="bad\('hotkey'\) \? 'true' : undefined"/)
})

test('G06: CSS rules for contrast, focus-visible, scrollbars, and disabled opacity', () => {
  // Contrast improvement for --text-3
  assert.match(stylesSource, /--text-3:\s*#8c8e96;/)

  // Focus-visible treatment
  assert.match(stylesSource, /:focus-visible\s*\{[\s\S]*?outline:\s*2px solid var\(--accent-fg\);/)

  // Scrollbar-gutter
  assert.match(slotsSource, /\.list\s*\{[\s\S]*?scrollbar-gutter:\s*stable;/)
  assert.match(slotsSource, /\.detail\s*\{[\s\S]*?scrollbar-gutter:\s*stable;/)

  // Avoid compounded fieldset disabled opacity
  assert.match(slotsSource, /button\[disabled\],\s*input\[disabled\],\s*select\[disabled\]\s*\{\s*opacity:\s*0\.5;\s*\}/)
  assert.doesNotMatch(slotsSource, /fieldset\[disabled\]\s*\{[\s\S]*?opacity:/)
})
