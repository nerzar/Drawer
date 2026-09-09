// Проверки двух правил из src/bridge/canonical.ts: порядок применения
// канонического state и судьба черновиков при его замене. Обе функции
// чистые, поэтому проверяются без Vue, без моста и без AHK.
//
// Запуск: npm test (esbuild собирает этот файл в node_modules/.cache,
// дальше встроенный тест-раннер node --test).

import assert from 'node:assert/strict'
import { test } from 'node:test'

import { CanonicalGate, reconcileSlotDrafts } from '../src/bridge/canonical'
import {
  draftPermanentValue,
  normalizeExe,
  resetPermanentIdentityFromSlot,
  resetToShared,
  setDraftExecutable,
  setDraftExecutableFromPicker,
  setDraftWindow,
  slotDraftsFromState,
  slotEditsToWire,
  type SlotDrafts,
} from '../src/bridge/slotDraft'
import type { PermanentSlotValue, SettingsState, SlotBehavior, SlotState } from '../src/bridge/protocol'
import { draftFromState } from '../src/bridge/general'

// ---------------------------- фикстуры ----------------------------

const behavior: SlotBehavior = {
  monitor: { kind: 'cursor' },
  edge: 'right',
  widthPercent: 60,
  activateOnShow: true,
  hideOnBlur: true,
}

function permValue(name: string, exe: string): PermanentSlotValue {
  return { ...behavior, name, executable: exe, windowClass: '', hotkey: 'Ctrl + Alt + F2' }
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
    hotkey: 'Ctrl + Alt + F2',
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
      animation: { style: 'classic', durationMs: 167, steps: 14 },
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
  assert.deepEqual(edits[0].kind === 'dynamic' && edits[0].value, { ...behavior, hotkey: 'Ctrl + Alt + F2' })
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

test('правка dynamic слота сохраняет поведение и hotkey номера', () => {
  const canonical = state(perm(1), dyn(2))
  const drafts = slotDraftsFromState(canonical)
  drafts[2]!.widthPercent = '35'

  const edits = slotEditsToWire(drafts, canonical)
  assert.equal(edits.length, 1)
  assert.equal(edits[0].kind, 'dynamic')
  const value = edits[0].kind === 'dynamic' ? edits[0].value : null
  assert.equal(value!.widthPercent, 35)
  assert.equal(value!.hotkey, 'Ctrl + Alt + F2')
  assert.equal(Object.keys(value!).length, 6, 'имени и exe у dynamic слота нет')
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

test('hotkey A -> B -> A lifecycle: draft emits edits upon change and after canonical adoption', () => {
  const initial = state(perm(1))
  const drafts = slotDraftsFromState(initial)
  assert.equal(drafts[1]!.hotkey, 'Ctrl + Alt + F2')

  // A -> B
  drafts[1]!.hotkey = 'Ctrl + Alt + Z'
  const editsB = slotEditsToWire(drafts, initial)
  assert.equal(editsB.length, 1)
  assert.equal(editsB[0].kind === 'permanent' && editsB[0].value.hotkey, 'Ctrl + Alt + Z')

  // Canonical adopts B (simulating successful Save and bridge adopt)
  const stateB = state({
    ...perm(1),
    value: { ...permValue('Steam', 'steam.exe'), hotkey: 'Ctrl + Alt + Z' },
  })
  const reconciled = reconcileSlotDrafts(drafts, stateB)
  assert.deepEqual(slotEditsToWire(reconciled, stateB), [])

  // B -> A
  reconciled[1]!.hotkey = 'Ctrl + Alt + F2'
  const editsA = slotEditsToWire(reconciled, stateB)
  assert.equal(editsA.length, 1)
  assert.equal(editsA[0].kind === 'permanent' && editsA[0].value.hotkey, 'Ctrl + Alt + F2')
})

test('resetToShared resets dynamic slot overrides to General defaults', () => {
  const customGeneralBehavior: SlotBehavior = {
    monitor: { kind: 'number', number: 2 },
    edge: 'bottom',
    widthPercent: 75,
    activateOnShow: false,
    hideOnBlur: false,
  }
  const canonical = state(dyn(1))
  const drafts = slotDraftsFromState(canonical)

  // Give slot 1 custom overrides different from General defaults
  drafts[1]!.edge = 'top'
  drafts[1]!.widthPercent = '40'
  drafts[1]!.activateOnShow = true
  drafts[1]!.hideOnBlur = true

  // Reset to General defaults
  resetToShared(drafts[1]!, customGeneralBehavior)

  assert.equal(drafts[1]!.monitorKind, 'number')
  assert.equal(drafts[1]!.monitorNumber, '2')
  assert.equal(drafts[1]!.edge, 'bottom')
  assert.equal(drafts[1]!.widthPercent, '75')
  assert.equal(drafts[1]!.activateOnShow, false)
  assert.equal(drafts[1]!.hideOnBlur, false)
})

// -------------------- G02: picker identity & stale windowClass --------------------

test('ручная смена exe гасит старый windowClass, а возврат восстанавливает', () => {
  const s = state(perm(1, 'Notepad', 'notepad.exe'))
  s.slots[0]!.value.windowClass = 'Notepad'
  const drafts = slotDraftsFromState(s)
  const d = drafts[1]!
  assert.equal(d.windowClass, 'Notepad')

  // Пользователь реально сменил exe вручную
  setDraftExecutable(d, 'calc.exe')
  assert.equal(d.executable, 'calc.exe')
  assert.equal(d.windowClass, '', 'stale windowClass должен быть очищен при смене exe')
  assert.equal(draftPermanentValue(d).windowClass, '')

  // Временный ввод / возврат к исходному exe восстанавливает валидный класс
  setDraftExecutable(d, 'notepad.exe')
  assert.equal(d.windowClass, 'Notepad', 'класс восстанавливается при возврате к исходному exe')
  assert.equal(draftPermanentValue(d).windowClass, 'Notepad')

  // Проверка нечувствительности к регистру и пробелам
  setDraftExecutable(d, '  NOTEPAD.EXE  ')
  assert.equal(d.windowClass, 'Notepad')
})

test('picker.exe при выборе нового exe сбрасывает старый windowClass и якорь', () => {
  const s = state(perm(1, 'Notepad', 'notepad.exe'))
  s.slots[0]!.value.windowClass = 'Notepad'
  const drafts = slotDraftsFromState(s)
  const d = drafts[1]!

  // Выбор нового exe через picker.exe
  setDraftExecutableFromPicker(d, 'calc.exe')
  assert.equal(d.executable, 'calc.exe')
  assert.equal(d.windowClass, '', 'stale class не должен остаться после picker.exe')
  assert.equal(d.classAnchorExe, '')
  assert.equal(d.anchorClass, '')

  // Последующий ввод notepad.exe уже не вернёт старый Notepad, так как якорь очищен
  setDraftExecutable(d, 'notepad.exe')
  assert.equal(d.windowClass, '')
})

test('picker.exe при повторном выборе того же exe сохраняет windowClass', () => {
  const s = state(perm(1, 'Notepad', 'notepad.exe'))
  s.slots[0]!.value.windowClass = 'Notepad'
  const drafts = slotDraftsFromState(s)
  const d = drafts[1]!

  setDraftExecutableFromPicker(d, 'NOTEPAD.EXE')
  assert.equal(d.windowClass, 'Notepad')
})

test('picker.window согласованно устанавливает exe, windowClass и засеивает имя', () => {
  const s = state(perm(1, 'Слот 1', 'notepad.exe'))
  const drafts = slotDraftsFromState(s)
  const d = drafts[1]!

  setDraftWindow(d, {
    title: 'Калькулятор',
    executable: 'calc.exe',
    windowClass: 'CalcFrame',
  }, 'Слот 1')

  assert.equal(d.executable, 'calc.exe')
  assert.equal(d.windowClass, 'CalcFrame')
  assert.equal(d.name, 'Калькулятор')

  const val = draftPermanentValue(d)
  assert.equal(val.executable, 'calc.exe')
  assert.equal(val.windowClass, 'CalcFrame')
})

test('dynamic->permanent использует чистый identity seed и не превращается в persistent до Apply', () => {
  const s = state(dyn(1))
  const drafts = slotDraftsFromState(s)
  const d = drafts[1]!

  // Черновик в dynamic
  assert.equal(d.kind, 'dynamic')
  assert.equal(d.name, 'Слот 1')
  assert.equal(d.executable, '')
  assert.equal(d.windowClass, '')

  // Переключение в permanent
  d.kind = 'permanent'
  resetPermanentIdentityFromSlot(d, s.slots[0]!)

  // На frontend exe/class не выдумываются
  assert.equal(d.name, 'Слот 1')
  assert.equal(d.executable, '')
  assert.equal(d.windowClass, '')

  // При отправке уезжает пустое значение, чтобы валидация backend осталась источником истины
  const edits = slotEditsToWire(drafts, s)
  assert.equal(edits.length, 1)
  assert.equal(edits[0]!.kind, 'permanent')
  assert.equal(edits[0]!.value.executable, '')
  assert.equal(edits[0]!.value.windowClass, '')
})

test('dynamic->permanent->dirty->dynamic->permanent возвращает чистый seed', () => {
  const s = state(dyn(1))
  const drafts = slotDraftsFromState(s)
  const d = drafts[1]!

  // Сделали permanent и набрали грязные правки
  d.kind = 'permanent'
  resetPermanentIdentityFromSlot(d, s.slots[0]!)
  setDraftWindow(d, { title: 'Tmp', executable: 'temp.exe', windowClass: 'TmpClass' }, 'Слот 1')
  assert.equal(d.executable, 'temp.exe')
  assert.equal(d.windowClass, 'TmpClass')

  // Передумали, вернули dynamic
  d.kind = 'dynamic'
  resetToShared(d, s.general.dynamicDefaults)
  resetPermanentIdentityFromSlot(d, s.slots[0]!)

  // Снова нажали «Сделать постоянным…» — данные должны быть чистым seed из permanentDefaults
  d.kind = 'permanent'
  resetPermanentIdentityFromSlot(d, s.slots[0]!)

  assert.equal(d.name, 'Слот 1')
  assert.equal(d.executable, '')
  assert.equal(d.windowClass, '')
})

test('pickSlot интеграция через bridge: очистка stale class и согласование окна', async () => {
  const s = state(perm(1, 'Notepad', 'notepad.exe'))
  s.slots[0]!.value.windowClass = 'Notepad'

  let requestHandler: (action: string, payload: any) => any = () => {}
  const listeners: ((ev: { data: any }) => void)[] = []

  ;(globalThis as any).chrome = {
    webview: {
      postMessage(msg: any) {
        if (msg.type === 'request') {
          Promise.resolve().then(() => {
            try {
              const res = requestHandler(msg.action, msg.payload)
              listeners.forEach((l) => l({ data: { type: 'response', id: msg.id, ok: true, result: res } }))
            } catch (err: any) {
              listeners.forEach((l) => l({ data: { type: 'response', id: msg.id, ok: false, error: { code: 'internal_error', message: err.message } } }))
            }
          })
        }
      },
      addEventListener(_type: string, handler: any) {
        listeners.push(handler)
      },
      removeEventListener(_type: string, handler: any) {
        const idx = listeners.indexOf(handler)
        if (idx >= 0) listeners.splice(idx, 1)
      },
    },
  }

  const { settings, pickSlot } = await import('../src/bridge/settings')
  settings.canonical = s
  settings.slotDrafts = slotDraftsFromState(s)
  const d = settings.slotDrafts[1]!
  assert.equal(d.windowClass, 'Notepad')

  // 1. pickSlot 'exe' выбирает новый executable -> stale windowClass гасится
  requestHandler = (action) => {
    if (action === 'picker.exe') return { selected: true, executable: 'calc.exe' }
    throw new Error('unexpected action ' + action)
  }
  await pickSlot(1, 'exe')
  assert.equal(d.executable, 'calc.exe')
  assert.equal(d.windowClass, '', 'picker.exe должен сбросить stale windowClass')

  // 2. pickSlot 'window' согласованно ставит exe и class
  requestHandler = (action) => {
    if (action === 'picker.window') {
      return {
        selected: true,
        window: { title: 'Calculator', executable: 'calc.exe', windowClass: 'CalcClass' },
      }
    }
    throw new Error('unexpected action ' + action)
  }
  await pickSlot(1, 'window')
  assert.equal(d.executable, 'calc.exe')
  assert.equal(d.windowClass, 'CalcClass')

  // 3. pickSlot 'exe' повторно выбирает тот же exe -> class сохраняется
  requestHandler = (action) => {
    if (action === 'picker.exe') return { selected: true, executable: 'CALC.EXE' }
    throw new Error('unexpected action ' + action)
  }
  await pickSlot(1, 'exe')
  assert.equal(d.windowClass, 'CalcClass')

  delete (globalThis as any).chrome
})

// ----------------- C03: partial/retryable/diagnostics lifecycle -----------------

test('C03-1: full success shows Сохранено, clears diagnostics and converges draft', async () => {
  const s1 = state(perm(1), dyn(2))
  const s2 = state(perm(1, 'Steam', 'steam.exe'), dyn(2))
  const reqHandler = (action: string, _payload: any): any => {
    if (action === 'settings.apply') {
      return {
        ok: true,
        result: {
          saved: true,
          changedFields: 2,
          changedSlots: [1],
          restartRequiredFields: [],
          diagnostics: [],
          state: s2,
        },
      }
    }
    throw new Error('unexpected action ' + action)
  }

  const listeners: any[] = []
  ;(globalThis as any).chrome = {
    webview: {
      postMessage(msg: any) {
        if (msg.type === 'request') {
          Promise.resolve().then(() => {
            const resp = reqHandler(msg.action, msg.payload)
            listeners.forEach((l) => l({ data: { type: 'response', id: msg.id, ...resp } }))
          })
        }
      },
      addEventListener(_t: string, h: any) { listeners.push(h) },
      removeEventListener(_t: string, h: any) {
        const idx = listeners.indexOf(h)
        if (idx >= 0) listeners.splice(idx, 1)
      },
    },
  }

  const { settings, applySettings, _resetClientForTesting } = await import('../src/bridge/settings')
  _resetClientForTesting()

  settings.canonical = s1
  settings.draft = draftFromState(s1.general)
  settings.slotDrafts = slotDraftsFromState(s1)
  settings.diagnostics = ['stale warning']
  settings.field = 'slots.1.name'

  // User edits Slot 1
  settings.slotDrafts[1]!.name = 'NewSteam'

  await applySettings()

  assert.equal(settings.status, 'ready')
  assert.equal(settings.bad, false)
  assert.match(settings.message, /Сохранено/)
  assert.equal(settings.diagnostics.length, 0, 'full success must clear resolved diagnostics')
  assert.equal(settings.field, '', 'full success must clear field diagnostic')
  assert.deepEqual(settings.canonical, s2)
  // Draft converged to canonical:
  assert.deepEqual(slotEditsToWire(settings.slotDrafts, settings.canonical), [])

  _resetClientForTesting()
  delete (globalThis as any).chrome
})

test('C03-2: partial/retryable result does not become false success and exposes diagnostics', async () => {
  const s1 = state(perm(1), dyn(2))
  const partialState = state(perm(1, 'SavedSlot', 'saved.exe'), dyn(2))

  const reqHandler = (action: string, _payload: any): any => {
    if (action === 'settings.apply') {
      return {
        ok: false,
        error: {
          code: 'write_failed',
          message: 'Не записалось: [slot2] exe',
          field: 'slots.2.executable',
          retryable: true,
          partial: { mayHavePersisted: true, runtimeReloaded: true },
          state: partialState,
          diagnostics: ['config.ini: [general] accent — неверный формат'],
        },
      }
    }
    throw new Error('unexpected action ' + action)
  }

  const listeners: any[] = []
  ;(globalThis as any).chrome = {
    webview: {
      postMessage(msg: any) {
        if (msg.type === 'request') {
          Promise.resolve().then(() => {
            const resp = reqHandler(msg.action, msg.payload)
            listeners.forEach((l) => l({ data: { type: 'response', id: msg.id, ...resp } }))
          })
        }
      },
      addEventListener(_t: string, h: any) { listeners.push(h) },
      removeEventListener(_t: string, h: any) {
        const idx = listeners.indexOf(h)
        if (idx >= 0) listeners.splice(idx, 1)
      },
    },
  }

  const { settings, applySettings, diagnosticsHint, _resetClientForTesting } = await import('../src/bridge/settings')
  _resetClientForTesting()

  settings.canonical = s1
  settings.draft = draftFromState(s1.general)
  settings.slotDrafts = slotDraftsFromState(s1)
  settings.slotDrafts[2]!.widthPercent = '80' // unpersisted retryable edit

  await applySettings()

  assert.equal(settings.status, 'error')
  assert.equal(settings.bad, true, 'partial save must remain visibly non-successful')
  assert.doesNotMatch(settings.message, /Сохранено/, 'partial failure must NEVER show Сохранено')
  assert.match(settings.message, /Не записалось: \[slot2\] exe/)
  assert.equal(settings.field, 'slots.2.executable', 'field diagnostic must be exposed')
  assert.deepEqual(settings.diagnostics, ['config.ini: [general] accent — неверный формат'])
  assert.match(diagnosticsHint(), /accent/)
  // Canonical was updated to partial reloaded state:
  assert.deepEqual(settings.canonical, partialState)
  // Retryable draft edit on slot 2 was NOT discarded:
  assert.equal(settings.slotDrafts[2]!.widthPercent, '80')

  _resetClientForTesting()
  delete (globalThis as any).chrome
})

test('C03-3: retryable draft and field diagnostic survive reload/reconcile', async () => {
  const s1 = state(perm(1), dyn(2))
  const reconciledState = state(perm(1), dyn(2))
  reconciledState.slots[0].status = { state: 'shown', windowTitle: 'Win', application: 'app' }

  const reqHandler = (action: string, _payload: any): any => {
    if (action === 'slot.bind') {
      return {
        ok: true,
        result: {
          slot: 1,
          status: { state: 'shown', windowTitle: 'Win', application: 'app' },
          state: reconciledState,
        },
      }
    }
    throw new Error('unexpected action ' + action)
  }

  const listeners: any[] = []
  ;(globalThis as any).chrome = {
    webview: {
      postMessage(msg: any) {
        if (msg.type === 'request') {
          Promise.resolve().then(() => {
            const resp = reqHandler(msg.action, msg.payload)
            listeners.forEach((l) => l({ data: { type: 'response', id: msg.id, ...resp } }))
          })
        }
      },
      addEventListener(_t: string, h: any) { listeners.push(h) },
      removeEventListener(_t: string, h: any) {
        const idx = listeners.indexOf(h)
        if (idx >= 0) listeners.splice(idx, 1)
      },
    },
  }

  const { settings, bindSlot, _resetClientForTesting } = await import('../src/bridge/settings')
  _resetClientForTesting()

  settings.canonical = s1
  settings.draft = draftFromState(s1.general)
  settings.slotDrafts = slotDraftsFromState(s1)
  settings.slotDrafts[2]!.widthPercent = '85' // retryable draft edit
  settings.field = 'slots.2.widthPercent'
  settings.diagnostics = ['warning from earlier']

  await bindSlot(1)

  assert.deepEqual(settings.canonical, reconciledState)
  assert.equal(settings.slotDrafts[2]!.widthPercent, '85', 'retryable draft must not be discarded by side reconcile')
  assert.equal(settings.field, 'slots.2.widthPercent', 'field diagnostic must survive side reconcile')
  assert.deepEqual(settings.diagnostics, ['warning from earlier'], 'warning must survive side reconcile')

  _resetClientForTesting()
  delete (globalThis as any).chrome
})

test('C03-4: unresolved warning and field diagnostic survive no-op/reconcile', async () => {
  const currentCanonical = state(perm(1), dyn(2))

  const reqHandler = (action: string, _payload: any): any => {
    if (action === 'settings.apply') {
      return {
        ok: true,
        result: {
          saved: false,
          changedFields: 0,
          changedSlots: [],
          restartRequiredFields: [],
          diagnostics: [], // AHK returns empty diagnostics on no-op
          state: currentCanonical,
        },
      }
    }
    throw new Error('unexpected action ' + action)
  }

  const listeners: any[] = []
  ;(globalThis as any).chrome = {
    webview: {
      postMessage(msg: any) {
        if (msg.type === 'request') {
          Promise.resolve().then(() => {
            const resp = reqHandler(msg.action, msg.payload)
            listeners.forEach((l) => l({ data: { type: 'response', id: msg.id, ...resp } }))
          })
        }
      },
      addEventListener(_t: string, h: any) { listeners.push(h) },
      removeEventListener(_t: string, h: any) {
        const idx = listeners.indexOf(h)
        if (idx >= 0) listeners.splice(idx, 1)
      },
    },
  }

  const { settings, applySettings, diagnosticsHint, _resetClientForTesting } = await import('../src/bridge/settings')
  _resetClientForTesting()

  settings.canonical = currentCanonical
  settings.draft = draftFromState(currentCanonical.general)
  settings.slotDrafts = slotDraftsFromState(currentCanonical)
  settings.slotDrafts[2]!.widthPercent = '90' // retryable draft edit
  settings.field = 'slots.2.widthPercent'
  settings.diagnostics = ['unresolved warning in config.ini']

  await applySettings()

  assert.equal(settings.status, 'ready')
  assert.match(settings.message, /Менять нечего/)
  assert.doesNotMatch(settings.message, /Сохранено/)
  assert.deepEqual(settings.diagnostics, ['unresolved warning in config.ini'], 'unresolved warning must survive no-op')
  assert.match(diagnosticsHint(), /unresolved warning/)
  assert.equal(settings.field, 'slots.2.widthPercent', 'unresolved field diagnostic must survive no-op')
  assert.equal(settings.slotDrafts[2]!.widthPercent, '90', 'retryable draft must survive no-op')

  _resetClientForTesting()
  delete (globalThis as any).chrome
})

test('C03-5: successful retry clears resolved diagnostic, field, and converges state', async () => {
  const currentCanonical = state(perm(1), dyn(2))
  const fixedCanonical = state(perm(1), dyn(2))
  fixedCanonical.slots[1].effective.widthPercent = 90

  const reqHandler = (action: string, _payload: any): any => {
    if (action === 'settings.apply') {
      return {
        ok: true,
        result: {
          saved: true,
          changedFields: 1,
          changedSlots: [2],
          restartRequiredFields: [],
          diagnostics: [], // resolved!
          state: fixedCanonical,
        },
      }
    }
    throw new Error('unexpected action ' + action)
  }

  const listeners: any[] = []
  ;(globalThis as any).chrome = {
    webview: {
      postMessage(msg: any) {
        if (msg.type === 'request') {
          Promise.resolve().then(() => {
            const resp = reqHandler(msg.action, msg.payload)
            listeners.forEach((l) => l({ data: { type: 'response', id: msg.id, ...resp } }))
          })
        }
      },
      addEventListener(_t: string, h: any) { listeners.push(h) },
      removeEventListener(_t: string, h: any) {
        const idx = listeners.indexOf(h)
        if (idx >= 0) listeners.splice(idx, 1)
      },
    },
  }

  const { settings, applySettings, diagnosticsHint, _resetClientForTesting } = await import('../src/bridge/settings')
  _resetClientForTesting()

  settings.canonical = currentCanonical
  settings.draft = draftFromState(currentCanonical.general)
  settings.slotDrafts = slotDraftsFromState(currentCanonical)
  settings.slotDrafts[2]!.widthPercent = '90'
  settings.field = 'slots.2.widthPercent'
  settings.diagnostics = ['unresolved warning in config.ini']

  await applySettings()

  assert.equal(settings.status, 'ready')
  assert.equal(settings.bad, false)
  assert.match(settings.message, /Сохранено/)
  assert.deepEqual(settings.diagnostics, [], 'successful retry clears resolved diagnostic')
  assert.equal(diagnosticsHint(), '')
  assert.equal(settings.field, '', 'successful retry clears field diagnostic')
  assert.deepEqual(settings.canonical, fixedCanonical)
  // State converged:
  assert.deepEqual(slotEditsToWire(settings.slotDrafts, settings.canonical), [])

  _resetClientForTesting()
  delete (globalThis as any).chrome
})

test('G03-1: in-flight save sets status=saving and adopt would discard mutations made during request', async () => {
  const customCanonical: SettingsState = {
    protocolVersion: 1,
    general: {
      dynamicDefaults: {
        monitor: { kind: 'cursor' },
        edge: 'right',
        widthPercent: 55,
        activateOnShow: true,
        hideOnBlur: true,
      },
      handlesEnabled: true,
      animation: { style: 'classic', durationMs: 167, steps: 14 },
      blurCheckMs: 250,
      accent: '2A2E35',
    },
    slots: [],
  }
  let resolveSave: ((v: any) => void) | null = null

  const listeners: any[] = []
  ;(globalThis as any).chrome = {
    webview: {
      postMessage(msg: any) {
        if (msg.type === 'request' && msg.action === 'settings.apply') {
          new Promise((resolve) => {
            resolveSave = resolve
          }).then((resp) => {
            listeners.forEach((l) => l({ data: { type: 'response', id: msg.id, ...resp } }))
          })
        }
      },
      addEventListener(_t: string, h: any) { listeners.push(h) },
      removeEventListener(_t: string, h: any) {
        const idx = listeners.indexOf(h)
        if (idx >= 0) listeners.splice(idx, 1)
      },
    },
  }

  const { settings, applySettings, _resetClientForTesting } = await import('../src/bridge/settings')
  _resetClientForTesting()

  settings.canonical = customCanonical
  settings.draft = draftFromState(customCanonical.general)
  settings.slotDrafts = slotDraftsFromState(customCanonical)

  const savePromise = applySettings()

  // In flight:
  assert.equal(settings.status, 'saving', 'status must be saving while request is in flight')

  // If a user mutation happened during flight:
  settings.draft!.widthPercent = '99'

  // Server responds with success and canonical state reflecting the snapshot:
  resolveSave!({
    ok: true,
    result: {
      saved: true,
      changedFields: 0,
      changedSlots: [],
      restartRequiredFields: [],
      diagnostics: [],
      state: customCanonical,
    },
  })

  await savePromise

  // Successful adopt resets draft from returned canonical state, proving mutation would be lost:
  assert.equal(settings.status, 'ready')
  assert.equal(settings.draft!.widthPercent, '55', 'unlocked in-flight mutation is lost by adopt, proving lock requirement')

  _resetClientForTesting()
  delete (globalThis as any).chrome
})

test('G03-2: GeneralView locks all save-participating inputs and actions during status=saving', async () => {
  const fs = await import('node:fs')
  const viewUrl = new URL('../src/views/GeneralView.vue', import.meta.url)
  const code = fs.readFileSync(viewUrl, 'utf8')

  // Saving computed definition
  assert.match(code, /const\s+saving\s*=\s*computed\(\(\)\s*=>\s*settings\.status\s*===\s*'saving'\)/, 'saving computed must track settings.status === saving')

  // Fieldset wrapper with :disabled="saving"
  assert.match(code, /<fieldset[^>]+class="[^"]*editor[^"]*"[^>]+:disabled="saving"/, 'editor fieldset must be bound to :disabled="saving"')

  // All participatory form controls bound to disabled
  const requiredTestIds = [
    'widthPercent',
    'edge',
    'monitorKind',
    'activateOnShow',
    'hideOnBlur',
    'handlesEnabled',
    'accent',
    'animationStyle',
    'animPreset',
    'animMs',
    'animSteps',
    'blurCheckMs',
  ]

  for (const tid of requiredTestIds) {
    const elRegex = new RegExp(`<[^>]+data-testid="${tid}"[^>]*>`, 's')
    const match = code.match(elRegex)
    assert.ok(match, `Element data-testid="${tid}" must exist in GeneralView.vue`)
    assert.ok(
      match[0].includes(':disabled="saving"') || match[0].includes('saving'),
      `Element data-testid="${tid}" must have disabled bound to saving`
    )
  }

  // Swatch buttons and custom color
  assert.match(code, /<button[^>]+class="swatch"[^>]+:disabled="saving"/, 'swatch buttons must be disabled when saving')
  assert.match(code, /ref="customColorInput"[^>]+:disabled="saving"/, 'custom color input must be disabled when saving')

  // Action handlers must guard against saving
  assert.match(code, /function\s+pickAccent[^{]+\{\s*if\s*\(\s*saving\.value\s*\)\s*return/, 'pickAccent must guard against saving')
  assert.match(code, /function\s+pickCustomAccent[^{]+\{\s*if\s*\(\s*saving\.value\s*\)\s*return/, 'pickCustomAccent must guard against saving')
  assert.match(code, /function\s+triggerCustomColor[^{]+\{\s*if\s*\(\s*saving\.value\s*\)\s*return/, 'triggerCustomColor must guard against saving')
  assert.match(code, /set:\s*\(v\)\s*=>\s*\{\s*if\s*\(\s*saving\.value\s*\)\s*return/, 'preset setter must guard against saving')
})

test('G03-3: General save lock lifecycle: locked during saving and unlocked after success or error', async () => {
  const currentCanonical = state(perm(1), dyn(2))
  let reqHandler: (action: string) => any = () => ({})

  const listeners: any[] = []
  ;(globalThis as any).chrome = {
    webview: {
      postMessage(msg: any) {
        if (msg.type === 'request') {
          Promise.resolve().then(() => {
            const resp = reqHandler(msg.action)
            listeners.forEach((l) => l({ data: { type: 'response', id: msg.id, ...resp } }))
          })
        }
      },
      addEventListener(_t: string, h: any) { listeners.push(h) },
      removeEventListener(_t: string, h: any) {
        const idx = listeners.indexOf(h)
        if (idx >= 0) listeners.splice(idx, 1)
      },
    },
  }

  const { settings, applySettings, _resetClientForTesting } = await import('../src/bridge/settings')
  _resetClientForTesting()

  settings.canonical = currentCanonical
  settings.draft = draftFromState(currentCanonical.general)
  settings.slotDrafts = slotDraftsFromState(currentCanonical)

  // 1. Success lifecycle
  reqHandler = () => ({
    ok: true,
    result: {
      saved: true,
      changedFields: 0,
      changedSlots: [],
      restartRequiredFields: [],
      diagnostics: [],
      state: currentCanonical,
    },
  })

  assert.notEqual(settings.status, 'saving')
  let p = applySettings()
  assert.equal(settings.status, 'saving', 'must be saving during apply')
  await p
  assert.notEqual(settings.status, 'saving', 'must unlock after successful apply')
  assert.equal(settings.status, 'ready')

  // 2. Error lifecycle
  reqHandler = () => ({
    ok: false,
    error: {
      code: 'ERR_WRITE_FAILED',
      message: 'Failed to write config',
      state: currentCanonical,
    },
  })

  p = applySettings()
  assert.equal(settings.status, 'saving', 'must be saving during second apply')
  await p
  assert.notEqual(settings.status, 'saving', 'must unlock after failed apply to allow retries')
  assert.equal(settings.status, 'error')

  _resetClientForTesting()
  delete (globalThis as any).chrome
})

