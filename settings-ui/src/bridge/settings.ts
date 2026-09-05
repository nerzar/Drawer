// Состояние Settings в терминах контракта: canonical — то, что
// применено в Ящике, draft — то, что набрано в форме. Владелец draft —
// Vue, владелец canonical — AHK; успешный Apply возвращает новый
// canonical, и он же становится новым baseline.
//
// Вкладка General ходит этим путём целиком: все её поля читаются из
// canonical, правятся в draft и уезжают одним settings.apply/ok. Slots
// имеют отдельный config draft и отправляют изменения через slotEdits.
//
// Каналов, приносящих canonical, четыре: загрузка, Save, bind/release и
// state из ошибки частичной записи. Порядок между ними и судьбу
// черновиков задаёт canonical.ts — здесь только два входа, которые этим
// правилам подчиняются: adopt (Save/загрузка) и absorb (всё остальное).

import { reactive } from 'vue'
import {
  ProtocolError,
  SettingsClient,
  hasWebViewTransport,
  webViewTransport,
} from './client'
import { CanonicalGate, reconcileSlotDrafts } from './canonical'
import { draftFromState, draftToWire, type GeneralDraft } from './general'
import type { SettingsState, SlotNumber } from './protocol'
import { slotDraftsFromState, slotEditsToWire, type SlotDrafts } from './slotDraft'

type Status = 'idle' | 'loading' | 'ready' | 'saving' | 'error'

export const settings = reactive({
  status: 'idle' as Status,
  connected: false,
  canonical: null as SettingsState | null,
  draft: null as GeneralDraft | null,
  slotDrafts: {} as SlotDrafts,
  pickerActive: false,
  closed: false,
  message: '',
  bad: false,
  // Путь поля из ответа — «general.blurCheckMs» и т. п. Подсвечивает
  // форма, сопоставляя его со своим контролом.
  field: '' as string,
  diagnostics: [] as string[],
  restartRequired: [] as string[],
  // Порт ответил closed:false — в черновике есть несохранённое. Вопрос
  // задаёт страница: MsgBox из моста заблокировал бы очередь сообщений
  // WebView на всё время раздумий.
  confirmDiscard: false,
})

let client: SettingsClient | null = null

// Один на окно: порядок ответов общий для всех каналов.
const gate = new CanonicalGate()

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
  api.on('settings.closed', () => { settings.closed = true; api.dispose() })
  const ticket = gate.issue()
  try {
    const state = await api.request('settings.getInitialState', {})
    if (gate.acceptSave(ticket)) adopt(state)
    settings.status = 'ready'
    settings.message = ''
  } catch (e) {
    fail(e, ticket)
  }
}

// OK — тот же Apply, только окно после успеха закрывается. Отдельного
// пути записи у него нет ни во Vue, ни в AHK.
export async function okSettings(): Promise<void> {
  await save('settings.ok')
}

export async function applySettings(): Promise<void> {
  await save('settings.apply')
}

// discard=false — «закрой, если терять нечего»: порт сравнит черновик с
// применённым состоянием и ответит closed:false, если есть что терять.
// Согласие человека приезжает вторым таким же запросом.
export async function cancelSettings(discard = false): Promise<void> {
  const api = settingsClient()
  if (!api) return
  try {
    // Черновика нет — состояние не успело загрузиться, терять нечего.
    const payload = settings.draft
      ? { draft: buildDraft(), discardChanges: discard }
      : { discardChanges: true }
    const result = await api.request('settings.cancel', payload)
    settings.confirmDiscard = !result.closed
  } catch (e) {
    fail(e, gate.issue())
  }
}

export function keepEditing(): void {
  settings.confirmDiscard = false
}

async function save(action: 'settings.apply' | 'settings.ok'): Promise<void> {
  const api = settingsClient()
  if (!api || !settings.draft || settings.pickerActive || settings.closed) return
  settings.status = 'saving'
  settings.message = 'Сохраняем…'
  settings.bad = false
  settings.field = ''
  settings.confirmDiscard = false
  const ticket = gate.issue()
  try {
    const result = await api.request(action, { draft: buildDraft() })
    // Канонический state приходит от AHK и заменяет baseline целиком:
    // Vue не вычисляет, что применилось, — он это узнаёт. Здесь же
    // черновик перестаёт быть грязным, потому что заводится заново из
    // того, что теперь действует. Снимок сделан после записи, поэтому
    // он авторитетен и отменяет все ответы, выданные до Save.
    if (gate.acceptSave(ticket)) adopt(result.state)
    settings.diagnostics = result.diagnostics ?? []
    settings.restartRequired = result.restartRequiredFields ?? []
    settings.status = 'ready'
    settings.message = result.saved
      ? `Сохранено. Изменённых строк: ${result.changedFields}`
      : 'Менять нечего: всё уже так'
  } catch (e) {
    fail(e, ticket)
  }
}

function buildDraft() {
  return { general: draftToWire(settings.draft!), slotEdits: slotEditsToWire(settings.slotDrafts, settings.canonical!) }
}

export async function pickSlot(number: SlotNumber, kind: 'exe' | 'window'): Promise<void> {
  const api = settingsClient()
  const draft = settings.slotDrafts[number]
  // Черновик есть у каждого слота, но exe и класс окна — поля только
  // постоянного: у динамического их некуда положить.
  if (!api || !draft || draft.kind !== 'permanent' || settings.pickerActive || settings.closed) return
  settings.pickerActive = true
  try {
    // User interaction has no RPC deadline. settings.closed disposes pending requests.
    if (kind === 'exe') {
      const result = await api.request('picker.exe', {}, 0)
      if (result.selected && !settings.closed && settings.slotDrafts[number] === draft)
        draft.executable = result.executable
    } else {
      const result = await api.request('picker.window', {}, 0)
      if (result.selected && !settings.closed && settings.slotDrafts[number] === draft) {
        draft.executable = result.window.executable
        draft.windowClass = result.window.windowClass
        if (!draft.name.trim() || draft.name.trim() === `Слот ${number}`)
          draft.name = result.window.title
      }
    }
  } catch (e) {
    if (!settings.closed) fail(e, gate.issue())
  } finally {
    settings.pickerActive = false
  }
}

export async function bindSlot(number: SlotNumber): Promise<void> {
  await slotRuntime('slot.bind', number, `Слот ${number} привязан к активному окну`)
}

export async function releaseSlot(number: SlotNumber): Promise<void> {
  await slotRuntime('slot.release', number, `Слот ${number} освобождён`)
}

// bind/release меняют рантайм, но не config: они возвращают снимок,
// снятый до любого последующего Save. Отсюда и правила — номер ответа
// решает, применять ли его, а черновики согласуются, а не пересобираются:
// несохранённая правка постоянного слота не должна исчезать от того, что
// человек привязал окно к соседнему.
async function slotRuntime(
  action: 'slot.bind' | 'slot.release',
  number: SlotNumber,
  done: string,
): Promise<void> {
  const api = settingsClient()
  if (!api || settings.status === 'saving' || settings.pickerActive || settings.closed) return
  settings.bad = false
  settings.field = ''
  const ticket = gate.issue()
  try {
    const result = await api.request(action, { slot: number })
    if (result.state && gate.acceptSide(ticket)) absorb(result.state)
    settings.message = done
  } catch (e) {
    fail(e, ticket)
  }
}

// Успешный Save и первая загрузка: применённое состояние становится
// baseline целиком, черновики заводятся заново из него. Всё, что было
// набрано и не уехало, здесь и заканчивается — потому что уехало.
function adopt(state: SettingsState): void {
  settings.canonical = state
  settings.draft = draftFromState(state.general)
  settings.slotDrafts = slotDraftsFromState(state)
}

// Канонический state пришёл мимо Save: baseline заменяется, черновики
// согласуются по правилу reconcileSlotDrafts. Черновик General не
// трогаем вовсе — у него нет рода, который мог бы смениться, и терять
// набранное не за что.
function absorb(state: SettingsState): void {
  settings.canonical = state
  settings.slotDrafts = reconcileSlotDrafts(settings.slotDrafts, state)
}

function fail(e: unknown, ticket: number): void {
  settings.status = 'error'
  settings.bad = true
  if (e instanceof ProtocolError) {
    settings.message = e.message
    settings.field = e.field ?? ''
    // Частичная запись с успешным reload приносит актуальный canonical:
    // baseline надо заменить, а draft — сохранить. Поэтому здесь absorb,
    // а не adopt: человек не должен второй раз набирать то, что не
    // уехало. Номер ответа проверяется так же, как у bind/release: этот
    // снимок тоже мог устареть, пока ошибка ехала.
    if (e.state && gate.acceptSide(ticket)) absorb(e.state)
    return
  }
  settings.field = ''
  settings.message = e instanceof Error ? e.message : String(e)
}

// Поля, которые начнут действовать только после перезапуска Ящика.
// General таких не содержит: реконсиляция перечитывает config.ini и
// применяет все его ключи сразу. Список приходит от AHK, а не
// вычисляется здесь, и пока его наполняет только focusHotkey слотов.
export function restartHint(): string {
  if (!settings.restartRequired.length) return ''
  const slots = settings.restartRequired
    .map((f) => /^slots\.(\d)\./.exec(f)?.[1])
    .filter((n): n is string => Boolean(n))
  return slots.length
    ? `Хоткей фокуса (слот${slots.length > 1 ? 'ы' : ''} ${slots.join(', ')}) заработает после перезапуска Ящика.`
    : 'Часть изменений заработает после перезапуска Ящика.'
}
