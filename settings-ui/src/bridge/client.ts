// Типизированный клиент Settings. Один запрос — один id, один ответ.
// Ответ связан с запросом только через id: WebView2 доставляет
// сообщения без порядка и без парности, поэтому «последний ответ = ответ
// на последний запрос» неверно даже при одном окне.

import type {
  ActionName,
  EventMessage,
  EventName,
  ProtocolErrorBody,
  RequestMap,
} from './protocol'

export class ProtocolError extends Error {
  readonly code: ProtocolErrorBody['code']
  readonly field?: string
  readonly retryable: boolean
  readonly partial?: ProtocolErrorBody['partial']
  readonly state?: ProtocolErrorBody['state']
  readonly diagnostics?: string[]

  constructor(body: ProtocolErrorBody) {
    super(body.message)
    this.name = 'ProtocolError'
    this.code = body.code
    this.field = body.field
    this.retryable = body.retryable
    this.partial = body.partial
    this.state = body.state
    this.diagnostics = body.diagnostics
  }
}

export interface SettingsTransport {
  post(message: unknown): void
  subscribe(handler: (message: unknown) => void): () => void
}

type WebViewHost = {
  postMessage(message: unknown): void
  addEventListener(type: 'message', handler: (event: { data: unknown }) => void): void
  removeEventListener(type: 'message', handler: (event: { data: unknown }) => void): void
}

function webviewHost(): WebViewHost | null {
  const chrome = (globalThis as { chrome?: { webview?: WebViewHost } }).chrome
  return chrome?.webview ?? null
}

export function hasWebViewTransport(): boolean {
  return webviewHost() !== null
}

// Транспорта нет только вне WebView2 — например, в `npm run dev`.
// Подставлять mock здесь нельзя: страница должна честно сказать, что
// backend недоступен, а не показать выдуманные настройки.
export function webViewTransport(): SettingsTransport {
  const host = webviewHost()
  if (!host) throw new Error('WebView2 недоступен: страница открыта не из Ящика')
  return {
    post(message) {
      host.postMessage(message)
    },
    subscribe(handler) {
      const listener = (event: { data: unknown }) => handler(event.data)
      host.addEventListener('message', listener)
      return () => host.removeEventListener('message', listener)
    },
  }
}

type Pending = {
  action: ActionName
  resolve: (value: never) => void
  reject: (reason: Error) => void
  timer: ReturnType<typeof setTimeout> | undefined
}

export class SettingsClient {
  private seq = 0
  private readonly pending = new Map<string, Pending>()
  private readonly listeners = new Map<EventName, Set<(data: never) => void>>()
  private readonly unsubscribe: () => void

  constructor(
    private readonly transport: SettingsTransport,
    private readonly timeoutMs = 10_000,
  ) {
    this.unsubscribe = transport.subscribe((message) => this.receive(message))
  }

  request<A extends ActionName>(
    action: A,
    payload: RequestMap[A]['payload'],
    timeoutMs = this.timeoutMs,
  ): Promise<RequestMap[A]['result']> {
    const id = `req-${++this.seq}`
    return new Promise<RequestMap[A]['result']>((resolve, reject) => {
      const timer = timeoutMs === 0 ? undefined : setTimeout(() => {
        this.pending.delete(id)
        reject(new Error(`Ящик не ответил на ${action} за ${timeoutMs} мс`))
      }, timeoutMs)
      this.pending.set(id, {
        action,
        resolve: resolve as (value: never) => void,
        reject,
        timer,
      })
      this.transport.post({ type: 'request', id, action, payload })
    })
  }

  on<E extends EventName>(
    event: E,
    handler: (data: Extract<EventMessage, { event: E }>['data']) => void,
  ): () => void {
    const set = this.listeners.get(event) ?? new Set()
    set.add(handler as (data: never) => void)
    this.listeners.set(event, set)
    return () => set.delete(handler as (data: never) => void)
  }

  dispose(): void {
    for (const [, entry] of this.pending) {
      clearTimeout(entry.timer)
      entry.reject(new Error('Клиент Settings закрыт'))
    }
    this.pending.clear()
    this.unsubscribe()
  }

  private receive(raw: unknown): void {
    const message = typeof raw === 'string' ? safeParse(raw) : raw
    if (!message || typeof message !== 'object') return

    // Пришло из транспорта, то есть снаружи: сужаем по полям, а не
    // доверяем объявленному типу.
    const envelope = message as {
      type?: unknown
      id?: unknown
      ok?: unknown
      result?: unknown
      error?: ProtocolErrorBody
      event?: unknown
      data?: unknown
    }

    if (envelope.type === 'event') {
      const set = this.listeners.get(envelope.event as EventName)
      if (set) for (const handler of set) handler(envelope.data as never)
      return
    }
    if (envelope.type !== 'response' || typeof envelope.id !== 'string') return

    const entry = this.pending.get(envelope.id)
    // Ответ на запрос, которого никто не ждёт: истёкший таймаут или
    // чужой id. Молча игнорируем — падать тут не на чем.
    if (!entry) return
    this.pending.delete(envelope.id)
    clearTimeout(entry.timer)

    if (envelope.ok) entry.resolve(envelope.result as never)
    else
      entry.reject(
        new ProtocolError(
          envelope.error ?? {
            code: 'internal_error',
            message: 'Ответ без ok и без error',
            retryable: false,
          },
        ),
      )
  }
}

function safeParse(text: string): unknown {
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}
