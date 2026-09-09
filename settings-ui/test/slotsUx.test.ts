import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import { hotkeyPresentation, isPendingDynamicConversion, isRuntimeDynamicBound } from '../src/bridge/slots'
import type { SlotState } from '../src/bridge/protocol'
import type { SlotDraft } from '../src/bridge/slotDraft'

const source = readFileSync(new URL('../src/views/SlotsView.vue', import.meta.url), 'utf8')

test('Slots UI keeps release action separate from the free-slot note and drops the retired override copy', () => {
  assert.match(source, /Сбросить слот/)
  assert.match(source, /снова находил приложение после перезапуска, закрепите слот за приложением/)
  assert.doesNotMatch(source, /Вернуть общие настройки/)
  assert.doesNotMatch(source, /привязанное окно останется/)
})

test('Slots UI does not expose internal slot vocabulary in rendered copy', () => {
  const template = source.match(/<template>([\s\S]*?)<style scoped>/)?.[1] ?? ''

  assert.doesNotMatch(template, /Динамический|Сделать динамическим/)
  assert.doesNotMatch(template, /show\/hide|ahk_class|\[dynamic(?:SlotN)?\]|\[slot N\]/)
  assert.match(template, /Постоянный' : 'Временный/)
  assert.match(template, /Сделать постоянным/)
})

test('narrow detail-actions still wraps after the override-box block was removed', () => {
  assert.match(source, /\.detail-actions\s*\{[\s\S]*?flex-wrap: wrap;/)
  assert.doesNotMatch(source, /\.override-box/)
  assert.doesNotMatch(source, /\.btn-reset-override/)
  assert.doesNotMatch(source, /\.hotkey-cap/)
})

const behavior = {
  monitor: { kind: 'cursor' as const },
  edge: 'left' as const,
  widthPercent: 50,
  activateOnShow: true,
  hideOnBlur: false,
}

const dynamicSlot = (hotkey: string): SlotState => ({
  number: 1,
  kind: 'dynamic',
  label: 'Слот 1',
  hotkey,
  effective: behavior,
  permanentDefaults: {
    ...behavior,
    name: 'App',
    executable: 'app.exe',
    windowClass: '',
    hotkey: 'Ctrl + Alt + 1',
  },
  status: { state: 'empty' },
})

const draftFor = (hotkey: string, baseKind: 'permanent' | 'dynamic' = 'dynamic'): SlotDraft => ({
  kind: 'dynamic',
  baseKind,
  name: 'App',
  executable: 'app.exe',
  windowClass: '',
  hotkey,
  widthPercent: '50',
  monitorKind: 'cursor',
  monitorNumber: '1',
  monitorRaw: '',
  edge: 'left',
  activateOnShow: true,
  hideOnBlur: false,
})

test('disabled and draft hotkeys never replace canonical active truth', () => {
  assert.deepEqual(hotkeyPresentation(dynamicSlot(''), draftFor('')), { active: '', pending: null })
  assert.deepEqual(
    hotkeyPresentation(dynamicSlot('Ctrl + Alt + 1'), draftFor('Ctrl + Alt + Z')),
    { active: 'Ctrl + Alt + 1', pending: 'Ctrl + Alt + Z' },
  )
})

test('pending permanent to temporary conversion is not runtime-bound', () => {
  const slot: SlotState = {
    number: 1,
    kind: 'permanent',
    value: {
      ...behavior,
      name: 'App',
      executable: 'app.exe',
      windowClass: '',
      hotkey: 'Ctrl + Alt + 1',
    },
    status: { state: 'applicationNotRunning', application: 'app.exe' },
  }
  assert.equal(isPendingDynamicConversion(slot, draftFor('Ctrl + Alt + 1', 'permanent')), true)
  assert.equal(isRuntimeDynamicBound(slot), false)
})
