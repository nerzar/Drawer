// Проверки двух правил из src/bridge/canonical.ts: порядок применения
// канонического state и судьба черновиков при его замене. Обе функции
// чистые, поэтому проверяются без Vue, без моста и без AHK.
//
// Запуск: npm test (esbuild собирает этот файл в node_modules/.cache,
// дальше встроенный тест-раннер node --test).

import assert from 'node:assert/strict'
import { test } from 'node:test'

import { CanonicalGate, reconcileSlotDrafts } from '../src/bridge/canonical'
import { resetToShared, slotDraftsFromState, slotEditsToWire, type SlotDrafts } from '../src/bridge/slotDraft'
import type { PermanentSlotValue, SettingsState, SlotBehavior, SlotState } from '../src/bridge/protocol'

// ---------------------------- фикстуры ----------------------------

const behavior: SlotBehavior = {
  monitor: { kind: 'cursor' },
  edge: 'right',
  widthPercent: 60,
  activateOnShow: true,
  hideOnBlur: true,
}

function permValue(name: string, exe: string): PermanentSlotValue {
  return { ...behavior, name, executable: exe, windowClass: '', focusHotkey: '' }
}

function perm(number: 1 | 2 | 3, name = 'Steam', exe = 'steam.exe'): SlotState {
  return { number, kind: 'permanent', value: permValue(name, exe), status: { state: 'empty' } }
}

function dyn(number: 1 | 2 | 3): SlotState {
  return {
    number,
    kind: 'dynamic',
    label: `Слот ${number}`,
    effective: behavior,
    permanentDefaults: permValue(`Слот ${number}`, ''),
    status: { state: 'empty' },
  }
}

function state(...slots: SlotState[]): SettingsState {
  return {
    protocolVersion: 1,
    general: {
      dynamicDefaults: behavior,
      handlesEnabled: true,
      animation: { durationMs: 160, steps: 14 },
      blurCheckMs: 250,
      accent: '2A2E35',
    },
    slots,
  }
}

// --------------------------- порядок ответов ---------------------------

test('ответ, выданный раньше уже принятого, отбрасывается', () => {
  const gate = new CanonicalGate()
  const first = gate.issue()
  const second = gate.issue()
  assert.equal(gate.acceptSide(second), true)
  assert.equal(gate.acceptSide(first), false, 'старый ответ не должен затирать новый')
})

test('ответы, пришедшие по порядку, принимаются оба', () => {
  const gate = new CanonicalGate()
  const first = gate.issue()
  const second = gate.issue()
  assert.equal(gate.acceptSide(first), true)
  assert.equal(gate.acceptSide(second), true)
})

test('Save применяется всегда и закрывает дорогу выданным до него', () => {
  const gate = new CanonicalGate()
  const bind = gate.issue()          // клик «привязать окно»
  const saveTicket = gate.issue()    // клик «Применить» до ответа на bind
  assert.equal(gate.acceptSave(saveTicket), true)
  assert.equal(gate.acceptSide(bind), false, 'снимок до записи не должен вернуть baseline назад')
})

test('Save авторитетен даже после принятого побочного ответа', () => {
  const gate = new CanonicalGate()
  const saveTicket = gate.issue()
  const bind = gate.issue()
  assert.equal(gate.acceptSide(bind), true)
  assert.equal(gate.acceptSave(saveTicket), true, 'снимок после записи применяется всегда')
  assert.equal(gate.acceptSide(bind), false, 'повторно тот же ответ не применяется')
})

// ------------------------- судьба черновиков -------------------------

test('слот остался постоянным — грязный черновик сохраняется', () => {
  const before = state(perm(1), dyn(2))
  const drafts = slotDraftsFromState(before)
  drafts[1]!.name = 'не сохранено'

  const next = reconcileSlotDrafts(drafts, state(perm(1), dyn(2)))
  assert.equal(next[1]!.name, 'не сохранено')
})

test('постоянный стал динамическим — черновик заводится заново', () => {
  const drafts = slotDraftsFromState(state(perm(1)))
  drafts[1]!.name = 'не сохранено'

  const next = reconcileSlotDrafts(drafts, state(dyn(1)))
  assert.equal(next[1]!.baseKind, 'dynamic', 'черновик описывал уже не тот слот')
  assert.equal(next[1]!.kind, 'dynamic')
  assert.notEqual(next[1]!.name, 'не сохранено')
})

test('динамический стал постоянным — черновик заводится из canonical', () => {
  const drafts: SlotDrafts = slotDraftsFromState(state(dyn(1)))
  assert.equal(drafts[1]!.baseKind, 'dynamic')

  const next = reconcileSlotDrafts(drafts, state(perm(1, 'Files', 'Files.exe')))
  assert.equal(next[1]!.baseKind, 'permanent')
  assert.equal(next[1]!.name, 'Files')
  assert.equal(next[1]!.executable, 'Files.exe')
})

test('смена рода у соседа не трогает чужой грязный черновик', () => {
  const drafts = slotDraftsFromState(state(perm(1), perm(2, 'Files', 'Files.exe')))
  drafts[2]!.executable = 'edited.exe'

  const next = reconcileSlotDrafts(drafts, state(dyn(1), perm(2, 'Files', 'Files.exe')))
  assert.equal(next[1]!.baseKind, 'dynamic')
  assert.equal(next[2]!.executable, 'edited.exe')
})

test('несохранённая смена рода переживает замену canonical мимо Save', () => {
  const before = state(perm(1), dyn(2))
  const drafts = slotDraftsFromState(before)
  drafts[1]!.kind = 'dynamic'          // человек нажал «Сделать динамическим»

  const next = reconcileSlotDrafts(drafts, state(perm(1), dyn(2)))
  assert.equal(next[1]!.kind, 'dynamic', 'намерение сменить род не сбрасывается')
  assert.equal(next[1]!.baseKind, 'permanent')
})

// --------------------- черновик и canonical раздельны ---------------------

test('правка черновика не меняет canonical DTO', () => {
  const canonical = state(perm(1))
  const drafts = slotDraftsFromState(canonical)
  drafts[1]!.name = 'изменено'
  drafts[1]!.monitorKind = 'number'
  drafts[1]!.monitorNumber = '2'

  const slot = canonical.slots[0]
  assert.equal(slot.kind === 'permanent' && slot.value.name, 'Steam')
  assert.equal(slot.kind === 'permanent' && slot.value.monitor.kind, 'cursor')
})

test('сразу после adopt правок нет: черновик равен применённому', () => {
  const canonical = state(perm(1), dyn(2))
  assert.deepEqual(slotEditsToWire(slotDraftsFromState(canonical), canonical), [])
})

test('изменённое поле уезжает ровно одной правкой своего слота', () => {
  const canonical = state(perm(1), perm(2, 'Files', 'Files.exe'))
  const drafts = slotDraftsFromState(canonical)
  drafts[2]!.widthPercent = '80'

  const edits = slotEditsToWire(drafts, canonical)
  assert.equal(edits.length, 1)
  assert.equal(edits[0].number, 2)
  assert.equal(edits[0].kind === 'permanent' && edits[0].value.widthPercent, 80)
})

test('после смены рода правка пересобранного черновика не уезжает', () => {
  const before = state(perm(1), perm(2, 'Files', 'Files.exe'))
  const drafts = slotDraftsFromState(before)
  drafts[1]!.name = 'не сохранено'

  const after = state(dyn(1), perm(2, 'Files', 'Files.exe'))
  assert.deepEqual(slotEditsToWire(reconcileSlotDrafts(drafts, after), after), [])
})

// -------------------------- смена рода --------------------------

test('«сделать динамическим» уезжает правкой рода с общим поведением', () => {
  const canonical = state(perm(1), dyn(2))
  const drafts = slotDraftsFromState(canonical)
  drafts[1]!.kind = 'dynamic'
  resetToShared(drafts[1]!, canonical.general.dynamicDefaults)

  const edits = slotEditsToWire(drafts, canonical)
  assert.equal(edits.length, 1)
  assert.equal(edits[0].number, 1)
  assert.equal(edits[0].kind, 'dynamic')
  assert.deepEqual(edits[0].kind === 'dynamic' && edits[0].value, behavior)
})

test('«сделать постоянным» уезжает полным значением из засева', () => {
  const canonical = state(perm(1), dyn(2))
  const drafts = slotDraftsFromState(canonical)
  drafts[2]!.kind = 'permanent'

  const edits = slotEditsToWire(drafts, canonical)
  assert.equal(edits.length, 1)
  assert.equal(edits[0].number, 2)
  assert.equal(edits[0].kind === 'permanent' && edits[0].value.name, 'Слот 2')
})

test('правка надстройки динамического слота уезжает пятью ключами поведения', () => {
  const canonical = state(perm(1), dyn(2))
  const drafts = slotDraftsFromState(canonical)
  drafts[2]!.widthPercent = '35'

  const edits = slotEditsToWire(drafts, canonical)
  assert.equal(edits.length, 1)
  assert.equal(edits[0].kind, 'dynamic')
  const value = edits[0].kind === 'dynamic' ? edits[0].value : null
  assert.equal(value!.widthPercent, 35)
  assert.equal(Object.keys(value!).length, 5, 'имени и exe у динамического слота нет')
})

test('динамический слот без правок в Save не едет', () => {
  const canonical = state(perm(1), dyn(2), dyn(3))
  assert.deepEqual(slotEditsToWire(slotDraftsFromState(canonical), canonical), [])
})

test('AHK key order does not make unchanged permanent or dynamic slots dirty', () => {
  const canonical = JSON.parse(JSON.stringify(state(perm(1), dyn(2)), (_key, value) =>
    value && typeof value === 'object' && !Array.isArray(value)
      ? Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b)))
      : value)) as SettingsState
  const drafts = slotDraftsFromState(canonical)
  assert.deepEqual(slotEditsToWire(drafts, canonical), [])
  drafts[2]!.widthPercent = '35'
  assert.deepEqual(slotEditsToWire(drafts, canonical).map((edit) => edit.number), [2])
})