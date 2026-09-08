// Путь config.ini и «Копировать путь» (TASK RUN-20260908-MUSE-SETTINGS-CONFIG-PATH-01).
//
// Запуск: npm test.

import assert from 'node:assert/strict'
import { test } from 'node:test'

import { copyConfigPath, fetchConfigPath, isConfigPath } from '../src/bridge/about'
import { SettingsClient } from '../src/bridge/client'
import type { SettingsTransport } from '../src/bridge/client'

const HOST_PATH = 'C:\\fullreset-test\\src\\config.ini'

// Минимальный транспорт: отвечает canned-результатом на два новых action,
// остальные действия отклоняет как unsupported.
function fakeTransport(respond: (action: string) => { ok: boolean; result?: unknown }): SettingsTransport {
  const listeners = new Set<(message: unknown) => void>()
  return {
    post(message) {
      const req = message as { id?: unknown; action?: unknown }
      if (typeof req.id !== 'string' || typeof req.action !== 'string') return
      const id = req.id
      const action = req.action
      queueMicrotask(() => {
        const r = respond(action)
        listeners.forEach((listener) =>
          listener(
            r.ok
              ? { type: 'response', id, action, ok: true, result: r.result }
              : { type: 'response', id, action, ok: false, error: r.result },
          ),
        )
      })
    },
    subscribe(handler) {
      listeners.add(handler)
      return () => listeners.delete(handler)
    },
  }
}

function hostTransport(): SettingsTransport {
  return fakeTransport((action) => {
    if (action === 'settings.getConfigPath' || action === 'settings.copyConfigPath') {
      return { ok: true, result: { path: HOST_PATH } }
    }
    return {
      ok: false,
      result: { code: 'unsupported_action', message: 'no', retryable: false },
    }
  })
}

test('getConfigPath возвращает путь host без вычислений во frontend', async () => {
  const api = new SettingsClient(hostTransport(), 0)
  try {
    const res = await api.request('settings.getConfigPath', {})
    assert.equal(res.path, HOST_PATH)
  } finally {
    api.dispose()
  }
})

test('copyConfigPath возвращает ту же строку host', async () => {
  const api = new SettingsClient(hostTransport(), 0)
  try {
    const res = await api.request('settings.copyConfigPath', {})
    assert.equal(res.path, HOST_PATH)
  } finally {
    api.dispose()
  }
})

test('fetchConfigPath: путь, пусто, ошибка транспорта', async () => {
  const okApi = new SettingsClient(hostTransport(), 0)
  try {
    assert.equal(await fetchConfigPath(okApi), HOST_PATH)
  } finally {
    okApi.dispose()
  }

  const emptyApi = new SettingsClient(
    fakeTransport(() => ({ ok: true, result: {} })),
    0,
  )
  try {
    assert.equal(await fetchConfigPath(emptyApi), null)
  } finally {
    emptyApi.dispose()
  }

  const failingApi = new SettingsClient(
    fakeTransport(() => ({
      ok: false,
      result: { code: 'internal_error', message: 'boom', retryable: false },
    })),
    0,
  )
  try {
    assert.equal(await fetchConfigPath(failingApi), null)
  } finally {
    failingApi.dispose()
  }
})

test('copyConfigPath helper: путь или null', async () => {
  const okApi = new SettingsClient(hostTransport(), 0)
  try {
    assert.equal(await copyConfigPath(okApi), HOST_PATH)
  } finally {
    okApi.dispose()
  }

  const failingApi = new SettingsClient(
    fakeTransport(() => ({
      ok: false,
      result: { code: 'internal_error', message: 'boom', retryable: false },
    })),
    0,
  )
  try {
    assert.equal(await copyConfigPath(failingApi), null)
  } finally {
    failingApi.dispose()
  }
})

test('isConfigPath принимает только непустую строку', () => {
  assert.equal(isConfigPath(HOST_PATH), true)
  assert.equal(isConfigPath(''), false)
  assert.equal(isConfigPath({}), false)
  assert.equal(isConfigPath(null), false)
  assert.equal(isConfigPath(undefined), false)
})
