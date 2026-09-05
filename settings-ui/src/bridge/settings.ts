// Состояние Settings в терминах контракта: canonical — то, что
// применено в Ящике, draft — то, что набрано в форме. Владелец draft —
// Vue, владелец canonical — AHK; успешный Apply возвращает новый
// canonical, и он же становится новым baseline.
//
// Slice правит одно поле — General.blurCheckMs. Остальные поля General
// уезжают в Apply теми значениями, что пришли из AHK, поэтому точечная
// запись backend не находит в них изменений и ничего не пишет.

import { reactive } from 'vue'
import {
  ProtocolError,
  SettingsClient,
  hasWebViewTransport,
  webViewTransport,
} from './client'
import type { GeneralSettings, SettingsState } from './protocol'

type Status = 'idle' | 'loading' | 'ready' | 'saving' | 'error'

export const settings = reactive({
  status: 'idle' as Status,
  connected: false,
  canonical: null as SettingsState | null,
  // blurCheckMs правится через input, а он отдаёт строку. Держим её как
  // есть и приводим к числу только на границе с wire: иначе «300abc»
  // молча стало бы 300 ещё до валидации.
  blurCheckMs: '' as string,
  message: '',
  bad: false,
  field: '' as string,
  diagnostics: [] as string[],
})

let client: SettingsClient | null = null

export function settingsClient(): SettingsClient | null {
  if (client) return client
  if (!hasWebViewTransport()) return null
  client = new SettingsClient(webViewTransport())
  return client
}

export async function loadSettings(): Promise<void> {
  const api = settingsClient()
  if (!api) {
    settings.status = 'error'
    settings.bad = true
    settings.message = 'Страница открыта не из Ящика: WebView2-мост недоступен'
    return
  }
  settings.connected = true
  settings.status = 'loading'
  settings.message = 'Читаем настройки…'
  settings.bad = false
  // Системный крестик не закрывает окно сам: AHK спрашивает, и ответить
  // должен фронтенд. Без этого закрытие ждало бы таймаута моста.
  api.on('settings.closeRequested', () => void cancelSettings())
  try {
    adopt(await api.request('settings.getInitialState', {}))
    settings.status = 'ready'
    settings.message = ''
  } catch (e) {
    fail(e)
  }
}

// OK — тот же Apply, только окно после успеха закрывается. Отдельного
// пути записи у него нет ни во Vue, ни в AHK.
export async function okSettings(): Promise<void> {
  await save('settings.ok')
}

export async function cancelSettings(): Promise<void> {
  const api = settingsClient()
  if (!api) return
  try {
    await api.request('settings.cancel', {})
  } catch (e) {
    fail(e)
  }
}

export async function applySettings(): Promise<void> {
  await save('settings.apply')
}

async function save(action: 'settings.apply' | 'settings.ok'): Promise<void> {
  const api = settingsClient()
  if (!api || !settings.canonical) return
  settings.status = 'saving'
  settings.message = 'Сохраняем…'
  settings.bad = false
  settings.field = ''
  try {
    const result = await api.request(action, { draft: buildDraft() })
    // Канонический state приходит от AHK и заменяет baseline целиком:
    // Vue не вычисляет, что применилось, — он это узнаёт.
    adopt(result.state)
    settings.diagnostics = result.diagnostics ?? []
    settings.status = 'ready'
    settings.message = result.saved
      ? `Сохранено. Изменённых строк: ${result.changedFields}`
      : 'Менять нечего: всё уже так'
  } catch (e) {
    fail(e)
  }
}

function buildDraft() {
  const general = settings.canonical!.general
  const blur = Number(settings.blurCheckMs)
  return {
    general: {
      ...general,
      // NaN уедет как null и вернётся структурированной ошибкой поля —
      // это правильнее, чем чинить ввод за пользователя.
      blurCheckMs: Number.isFinite(blur) ? blur : Number.NaN,
    } satisfies GeneralSettings,
    slotEdits: [],
  }
}

function adopt(state: SettingsState): void {
  settings.canonical = state
  settings.blurCheckMs = String(state.general.blurCheckMs)
}

function fail(e: unknown): void {
  settings.status = 'error'
  settings.bad = true
  if (e instanceof ProtocolError) {
    settings.message = e.message
    settings.field = e.field ?? ''
    // Частичная запись с успешным reload приносит актуальный canonical:
    // baseline надо заменить, а draft — сохранить.
    if (e.state) settings.canonical = e.state
    return
  }
  settings.field = ''
  settings.message = e instanceof Error ? e.message : String(e)
}
