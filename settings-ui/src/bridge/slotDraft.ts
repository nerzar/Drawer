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
  classAnchorExe?: string
  anchorClass?: string
  hotkey: string
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
    classAnchorExe: named.windowClass ? named.executable : '',
    anchorClass: named.windowClass || '',
    hotkey: slot.kind === 'permanent' ? named.hotkey : slot.hotkey,
    ...behaviorFields(behavior),
  }
}

export function slotDraftsFromState(state: SettingsState): SlotDrafts {
  const drafts: SlotDrafts = {}
  for (const slot of state.slots) drafts[slot.number] = draftFromSlot(slot)
  return drafts
}

export function normalizeExe(exe: string): string {
  return exe.trim().toLowerCase()
}

// Ручной ввод exe: при смене исполняемого файла старый класс окна гасится;
// при возврате к файлу, которому этот класс принадлежал, класс восстанавливается.
export function setDraftExecutable(draft: SlotDraft, nextExe: string): void {
  draft.executable = nextExe
  const normalizedNext = normalizeExe(nextExe)
  const normalizedAnchor = normalizeExe(draft.classAnchorExe || '')
  if (draft.anchorClass && normalizedNext && normalizedNext === normalizedAnchor) {
    draft.windowClass = draft.anchorClass
  } else {
    draft.windowClass = ''
  }
}

// Выбор exe через picker.exe: если выбран новый exe, старый класс окна
// и якорь очищаются целиком; если выбран тот же exe, класс не теряется.
export function setDraftExecutableFromPicker(draft: SlotDraft, nextExe: string): void {
  const prevNormalized = normalizeExe(draft.executable)
  const nextNormalized = normalizeExe(nextExe)
  if (prevNormalized !== nextNormalized) {
    draft.classAnchorExe = ''
    draft.anchorClass = ''
    draft.windowClass = ''
  }
  draft.executable = nextExe
}

// Выбор окна через picker.window: согласует exe и класс из одного окна,
// обновляет якорь и при необходимости засеивает имя.
export function setDraftWindow(
  draft: SlotDraft,
  window: { title: string; executable: string; windowClass: string },
  defaultName?: string,
): void {
  draft.executable = window.executable
  draft.windowClass = window.windowClass
  draft.classAnchorExe = window.executable
  draft.anchorClass = window.windowClass
  if (!draft.name.trim() || (defaultName && draft.name.trim() === defaultName)) {
    draft.name = window.title
  }
}

// Чистый засев постоянной идентичности из canonical (permanentDefaults для dynamic)
export function resetPermanentIdentityFromSlot(draft: SlotDraft, slot: SlotState): void {
  const named = slot.kind === 'permanent' ? slot.value : slot.permanentDefaults
  draft.name = named.name
  draft.executable = named.executable
  draft.windowClass = named.windowClass
  draft.classAnchorExe = named.windowClass ? named.executable : ''
  draft.anchorClass = named.windowClass || ''
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
  const normalizedExe = normalizeExe(d.executable)
  const normalizedAnchor = normalizeExe(d.classAnchorExe || '')
  let windowClass = d.windowClass
  if (d.classAnchorExe && normalizedExe !== normalizedAnchor) {
    windowClass = ''
  }
  return {
    ...draftBehavior(d),
    name: d.name,
    executable: d.executable,
    windowClass,
    hotkey: d.hotkey,
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
    const value = { ...draftBehavior(draft), hotkey: draft.hotkey }
    // effective уже включает надстройку [dynamicSlotN], если она есть, —
    // значит расхождение с ним и есть незаписанная правка надстройки.
    if (slot.kind !== 'dynamic' || !same(value, { ...slot.effective, hotkey: slot.hotkey }))
      edits.push({ number: slot.number, kind: 'dynamic', value })
  }
  return edits
}
