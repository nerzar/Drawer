// Wire-контракт Settings. Единственное описание того, что ходит между
// Vue и AHK; см. docs/settings-integration-layer.md. Внутренних имён
// Drawer здесь нет по построению: ни exe/cls/width, ни INI-секций, ни
// HWND — только смысловые поля.

export const ERROR_CODES = [
  'invalid_request',
  'unsupported_action',
  'validation_error',
  'write_failed',
  'verify_failed',
  'busy',
  'slot_is_permanent',
  'no_eligible_active_window',
  'not_bound',
  'internal_error',
] as const

export type ErrorCode = (typeof ERROR_CODES)[number]

export type SlotNumber = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
export type Edge = 'left' | 'right' | 'top' | 'bottom'

// invalid — значение из config.ini, которого не бывает у контролов:
// AHK не притворяется, что там cursor, потому что показ такого слота
// падает. Форма обязана дать выбрать заново.
export type MonitorRef =
  | { kind: 'cursor' }
  | { kind: 'number'; number: number }
  | { kind: 'invalid'; raw: string }

export type SlotBehavior = {
  monitor: MonitorRef
  edge: Edge
  widthPercent: number
  activateOnShow: boolean
  hideOnBlur: boolean
}

// steps: 0 — анимации нет; отдельного «выключено» на wire не нужно.
// accent — шесть hex-цифр без «#», как в config.ini; «#» добавляет CSS.
export type GeneralSettings = {
  dynamicDefaults: SlotBehavior
  handlesEnabled: boolean
  animation: { durationMs: number; steps: number }
  blurCheckMs: number
  accent: string
}

export type PermanentSlotValue = SlotBehavior & {
  name: string
  executable: string
  windowClass: string
  focusHotkey: string
}

export type SlotStatus =
  | { state: 'empty' | 'applicationNotRunning' }
  | { state: 'available' | 'parked' | 'shown'; windowTitle: string }

export type SlotState =
  | {
      number: SlotNumber
      kind: 'dynamic'
      label: string
      effective: SlotBehavior
      permanentDefaults: PermanentSlotValue
      status: SlotStatus
    }
  | {
      number: SlotNumber
      kind: 'permanent'
      value: PermanentSlotValue
      status: SlotStatus
    }

export type SettingsState = {
  protocolVersion: 1
  general: GeneralSettings
  slots: SlotState[]
}

export type SlotEdit =
  | { number: SlotNumber; kind: 'dynamic' }
  | { number: SlotNumber; kind: 'permanent'; value: PermanentSlotValue }

export type SettingsDraft = { general: GeneralSettings; slotEdits: SlotEdit[] }

export type RestartRequiredField = `slots.${SlotNumber}.focusHotkey`

export type SaveResult = {
  saved: boolean
  changedFields: number
  changedSlots: SlotNumber[]
  restartRequiredFields: RestartRequiredField[]
  // Замечания к перечитанному config.ini. Расширение контракта поверх
  // ADR: с C5 загрузка их возвращает, а не показывает MsgBox'ом, и
  // потерять их по дороге к пользователю было бы жаль.
  diagnostics: string[]
  state: SettingsState
}

export type ProtocolErrorBody = {
  code: ErrorCode
  message: string
  field?: string
  retryable: boolean
  // Появляется только после начатой записи: rollback не обещан.
  partial?: { mayHavePersisted: true; runtimeReloaded: boolean }
  // Приходит только когда рантайм действительно перечитан.
  state?: SettingsState
}

// Карта action -> payload/result. Она и делает клиента типизированным:
// request('settings.apply', ...) возвращает SaveResult, а не unknown.
export type RequestMap = {
  'picker.exe': {
    payload: Record<string, never>
    result: { selected: false } | { selected: true; executable: string }
  }
  'picker.window': {
    payload: Record<string, never>
    result: { selected: false } | { selected: true; window: { title: string; executable: string; windowClass: string } }
  }
  'slot.watchStatus': {
    payload: { enabled: boolean }
    result: { enabled: boolean }
  }
  'settings.getInitialState': {
    payload: Record<string, never>
    result: SettingsState
  }
  'settings.apply': {
    payload: { draft: SettingsDraft }
    result: SaveResult
  }
  'settings.ok': {
    payload: { draft: SettingsDraft }
    result: SaveResult & { closing: true }
  }
  // Закрытие без записи. Сравнивает draft с применённым состоянием AHK:
  // closed:false означает «в черновике есть несохранённое, окно пока не
  // закрываю». Согласие человека выбросить правки приезжает вторым таким
  // же запросом с discardChanges: спрашивает WebView, решает порт.
  'settings.cancel': {
    payload: { draft?: SettingsDraft; discardChanges?: boolean }
    result: { closed: boolean }
  }
}

export type ActionName = keyof RequestMap

export type ResponseMessage = {
  type: 'response'
  id: string
  action: string
  ok: boolean
  result?: unknown
  error?: ProtocolErrorBody
}

export type EventMessage =
  | { type: 'event'; event: 'slot.statusChanged'; data: { slot: SlotNumber; status: SlotStatus } }
  | { type: 'event'; event: 'settings.closeRequested'; data: { reason: 'window' } }
  | {
      type: 'event'
      event: 'settings.closed'
      data: {
        reason: 'ok' | 'cancel' | 'drawerExit' | 'nativeCloseTimeout'
        origin: 'frontend' | 'nativeWindow' | 'host'
        forced: boolean
      }
    }

export type EventName = EventMessage['event']
