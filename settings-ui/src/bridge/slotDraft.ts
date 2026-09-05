// Черновик слота: то, что набрано в форме, против canonical, который
// принадлежит AHK. Черновик есть у каждого слота, а не только у
// постоянного, — иначе род слота нельзя было бы поменять, не выдумав
// для этого второго механизма.
//
// kind — род, который человек хочет; baseKind — род, которым слот был в
// canonical, откуда черновик заведён. Их расхождение и есть незаписанная
// смена рода; baseKind же отвечает на вопрос, устарел ли черновик, когда
// canonical заменился мимо Save (см. canonical.ts).

import { monitorToWire, num, type MonitorKind } from './general'
import type {
  Edge,
  PermanentSlotValue,
  SettingsState,
  SlotBehavior,
  SlotEdit,
  SlotNumber,
  SlotState,
} from './protocol'

export type SlotKind = 'permanent' | 'dynamic'

export type SlotDraft = {
  kind: SlotKind
  baseKind: SlotKind
  name: string
  executable: string
  windowClass: string
  focusHotkey: string
  widthPercent: string
  monitorKind: MonitorKind
  monitorNumber: string
  monitorRaw: string
  edge: Edge
  activateOnShow: boolean
  hideOnBlur: boolean
}

export type SlotDrafts = Partial<Record<SlotNumber, SlotDraft>>

// Числа живут в черновике строками по той же причине, что и в General:
// приведение к числу до отправки чинило бы ввод за пользователя.
function behaviorFields(b: SlotBehavior) {
  return {
    widthPercent: String(b.widthPercent),
    monitorKind: b.monitor.kind,
    monitorNumber: b.monitor.kind === 'number' ? String(b.monitor.number) : '1',
    monitorRaw: b.monitor.kind === 'invalid' ? b.monitor.raw : '',
    edge: b.edge,
    activateOnShow: b.activateOnShow,
    hideOnBlur: b.hideOnBlur,
  }
}

function draftFromSlot(slot: SlotState): SlotDraft {
  // У динамического слота имени, exe и хоткея нет. Берём их из засева,
  // которым AHK заполняет панель «Сделать постоянным», — форма не должна
  // выдумывать умолчания сама.
  const named = slot.kind === 'permanent' ? slot.value : slot.permanentDefaults
  const behavior = slot.kind === 'permanent' ? slot.value : slot.effective
  return {
    kind: slot.kind,
    baseKind: slot.kind,
    name: named.name,
    executable: named.executable,
    windowClass: named.windowClass,
    focusHotkey: named.focusHotkey,
    ...behaviorFields(behavior),
  }
}

export function slotDraftsFromState(state: SettingsState): SlotDrafts {
  const drafts: SlotDrafts = {}
  for (const slot of state.slots) drafts[slot.number] = draftFromSlot(slot)
  return drafts
}

// Поведение слота из черновика: пять ключей, которые понимает и
// [slotN], и [dynamicSlotN].
export function draftBehavior(d: SlotDraft): SlotBehavior {
  return {
    monitor: monitorToWire(d),
    edge: d.edge,
    widthPercent: num(d.widthPercent),
    activateOnShow: d.activateOnShow,
    hideOnBlur: d.hideOnBlur,
  }
}

export function draftPermanentValue(d: SlotDraft): PermanentSlotValue {
  return {
    ...draftBehavior(d),
    name: d.name,
    executable: d.executable,
    windowClass: d.windowClass,
    focusHotkey: d.focusHotkey,
  }
}

// Возврат к общим настройкам динамических слотов. Так же поступает
// native при «Сделать динамическим»: секция [slotN] уходит, собственной
// надстройки у слота не появляется.
export function resetToShared(d: SlotDraft, shared: SlotBehavior): void {
  Object.assign(d, behaviorFields(shared))
}

// JSON objects have no key order; AHK's Map serializes in a different
// order from the draft. Compare fields so an unchanged slot stays clean.
function same<T extends object>(a: T, b: T): boolean {
  return (Object.keys(a) as (keyof T)[]).every((key) =>
    JSON.stringify(a[key]) === JSON.stringify(b[key]))
}

// Правки, которые уедут в Save. Слот попадает в список, если сменил род
// или если его значения разошлись с применёнными: сравнение идёт с
// canonical, а не с моментом открытия формы.
export function slotEditsToWire(drafts: SlotDrafts, state: SettingsState): SlotEdit[] {
  const edits: SlotEdit[] = []
  for (const slot of state.slots) {
    const draft = drafts[slot.number]
    if (!draft) continue
    if (draft.kind === 'permanent') {
      const value = draftPermanentValue(draft)
      if (slot.kind !== 'permanent' || !same(value, slot.value))
        edits.push({ number: slot.number, kind: 'permanent', value })
      continue
    }
    const value = draftBehavior(draft)
    // effective уже включает надстройку [dynamicSlotN], если она есть, —
    // значит расхождение с ним и есть незаписанная правка надстройки.
    if (slot.kind !== 'dynamic' || !same(value, slot.effective))
      edits.push({ number: slot.number, kind: 'dynamic', value })
  }
  return edits
}
