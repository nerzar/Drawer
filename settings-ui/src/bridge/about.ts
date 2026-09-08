// Логика вкладки «О программе» без Vue: путь к config.ini приходит
// только от host через типизированные actions settings.getConfigPath /
// settings.copyConfigPath. Невалидный ответ или ошибка транспорта —
// это «путь недоступен», а не выдуманное значение.

import type { SettingsClient } from './client'

export function isConfigPath(value: unknown): value is string {
  return typeof value === 'string' && value.length > 0
}

type Api = Pick<SettingsClient, 'request'>

export async function fetchConfigPath(api: Api): Promise<string | null> {
  try {
    const res = await api.request('settings.getConfigPath', {})
    return isConfigPath(res.path) ? res.path : null
  } catch {
    return null
  }
}

export async function copyConfigPath(api: Api): Promise<string | null> {
  try {
    const res = await api.request('settings.copyConfigPath', {})
    return isConfigPath(res.path) ? res.path : null
  } catch {
    return null
  }
}
