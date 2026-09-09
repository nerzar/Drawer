import type {
  Edge,
  GeneralSettings,
  PermanentSlotValue,
  RequestMap,
  SettingsDraft,
  SettingsState,
  SlotBehavior,
  SlotNumber,
  SlotState,
} from './protocol'
import type { SettingsTransport } from './client'

const edges: Edge[] = ['left', 'right', 'top', 'bottom']
const monitors = [
  { kind: 'cursor' as const },
  { kind: 'number' as const, number: 1 },
  { kind: 'number' as const, number: 2 },
]

const sharedBehavior: SlotBehavior = {
  monitor: monitors[0],
  edge: 'left',
  widthPercent: 30,
  activateOnShow: true,
  hideOnBlur: true,
}

const general: GeneralSettings = {
  dynamicDefaults: sharedBehavior,
  handlesEnabled: true,
  animation: { style: 'dwmSlideFade', durationMs: 167, steps: 14 },
  blurCheckMs: 120,
  accent: '2A2E35',
  handle: { width: 22, height: 34, gap: 8 },
}

function permanentValue(number: SlotNumber): PermanentSlotValue {
  return {
    name: number === 1 ? 'Visual Studio Code' : `Приложение ${number}`,
    executable: number === 1 ? 'Code.exe' : '',
    windowClass: number === 1 ? 'Chrome_WidgetWin_1' : '',
    hotkey: `Ctrl + Alt + ${number}`,
    monitor: { kind: 'cursor' },
    edge: edges[(number - 1) % edges.length],
    widthPercent: 30,
    activateOnShow: true,
    hideOnBlur: true,
  }
}

function emptyStatus(): SlotState['status'] {
  return { state: 'empty' }
}

function makeSlot(number: SlotNumber): SlotState {
  if (number === 1) {
    return {
      number,
      kind: 'permanent',
      value: permanentValue(number),
      status: {
        state: 'available',
        windowTitle: 'Visual Studio Code',
        application: 'Visual Studio Code',
      },
    }
  }

  return {
    number,
    kind: 'dynamic',
    label: number === 2 ? 'Динамический слот' : `Свободный слот ${number}`,
    effective: { ...sharedBehavior },
    hotkey: `Ctrl + Alt + ${number}`,
    permanentDefaults: permanentValue(number),
    status: emptyStatus(),
  }
}

let state: SettingsState = {
  protocolVersion: 1,
  general,
  slots: [1, 2, 3, 4, 5, 6, 7, 8, 9].map((number) => makeSlot(number as SlotNumber)),
}

export function devTransport(): SettingsTransport {
  const listeners = new Set<(message: unknown) => void>()

  return {
    post(message) {
      const request = message as { id?: unknown; action?: unknown; payload?: unknown }
      if (typeof request.id !== 'string' || typeof request.action !== 'string') return
      queueMicrotask(() => {
        const result = respond(request.action as keyof RequestMap, request.payload)
        listeners.forEach((listener) => listener({
          type: 'response',
          id: request.id,
          action: request.action,
          ok: true,
          result,
        }))
      })
    },
    subscribe(handler) {
      listeners.add(handler)
      return () => listeners.delete(handler)
    },
  }
}

function respond(action: keyof RequestMap, payload: unknown): unknown {
  switch (action) {
    case 'settings.getInitialState':
      return clone(state)
    case 'settings.apply':
    case 'settings.ok': {
      const draft = (payload as { draft?: SettingsDraft }).draft
      if (draft) state = applyDraft(draft)
      return {
        saved: Boolean(draft),
        changedFields: draft ? 1 : 0,
        changedSlots: [],
        restartRequiredFields: [],
        diagnostics: [],
        state: clone(state),
        ...(action === 'settings.ok' ? { closing: true } : {}),
      }
    }
    case 'settings.cancel':
      return { closed: Boolean((payload as { discardChanges?: boolean }).discardChanges) }
    case 'slot.bind':
    case 'slot.release': {
      const number = (payload as { slot: SlotNumber }).slot
      const slot = state.slots.find((item) => item.number === number)
      if (action === 'slot.release' && slot?.kind === 'dynamic') {
        slot.status = emptyStatus()
      }
      return { slot: number, status: slot?.status ?? emptyStatus(), state: clone(state) }
    }
    case 'slot.watchStatus':
      return { enabled: Boolean((payload as { enabled?: boolean }).enabled) }
    case 'picker.exe':
    case 'picker.window':
      return { selected: false }
    default:
      return {}
  }
}

function applyDraft(draft: SettingsDraft): SettingsState {
  const next = clone(state)
  next.general = draft.general
  for (const edit of draft.slotEdits) {
    const index = next.slots.findIndex((item) => item.number === edit.number)
    if (index < 0) continue
    const slot = next.slots[index]
    if (edit.kind === 'permanent') {
      next.slots[index] = { ...slot, kind: 'permanent', value: edit.value }
    } else if (slot.kind === 'dynamic') {
      next.slots[index] = { ...slot, effective: edit.value, hotkey: edit.value.hotkey }
    } else {
      next.slots[index] = {
        number: slot.number,
        kind: 'dynamic',
        label: slot.value.name,
        effective: edit.value,
        hotkey: edit.value.hotkey,
        permanentDefaults: slot.value,
        status: slot.status,
      }
    }
  }
  return next
}

function clone<T>(value: T): T {
  return structuredClone(value)
}
