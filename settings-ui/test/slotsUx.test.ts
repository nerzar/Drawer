import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const source = readFileSync(new URL('../src/views/SlotsView.vue', import.meta.url), 'utf8')

test('Slots UI explains temporary binding and separates release from reset', () => {
  assert.match(source, /Слот свободен\./)
  assert.match(source, /Ctrl \+ Alt \+ Shift \+ \{\{ selectedSlot\.number \}\}/)
  assert.match(source, /Отвязать окно/)
  assert.match(source, /Вернуть общие настройки/)
  assert.match(source, /привязанное окно останется/)
})

test('Slots UI does not expose internal slot vocabulary in rendered copy', () => {
  const template = source.match(/<template>([\s\S]*?)<style scoped>/)?.[1] ?? ''

  assert.doesNotMatch(template, /Динамический|Сделать динамическим/)
  assert.doesNotMatch(template, /show\/hide|ahk_class|\[dynamic(?:SlotN)?\]|\[slot N\]/)
  assert.match(template, /Постоянный' : 'Временный/)
  assert.match(template, /Закрепить за приложением…/)
})

test('narrow reset block removes label offset and permits wrapping', () => {
  assert.match(source, /\.override-box \.hotkey-cap\s*\{\s*margin: 0;/)
  assert.match(source, /\.override-box\s*\{[\s\S]*?flex-wrap: wrap;/)
  assert.match(source, /\.detail-actions\s*\{[\s\S]*?flex-wrap: wrap;/)
  assert.match(source, /\.btn-reset-override\s*\{[\s\S]*?white-space: normal;/)
})
