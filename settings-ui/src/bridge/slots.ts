import { onUnmounted, ref, watch } from 'vue'
import { settings, settingsClient } from './settings'
import type { MonitorRef, SlotState, SlotStatus } from './protocol'

export function useSlotStatus() {
  const error = ref('')
  let stop: (() => void) | undefined
  let active = true
  let started = false
  watch(() => Boolean(settings.canonical), (ready) => {
    const api = settingsClient()
    if (!ready || !api || started) return
    started = true
    // Subscribe before enabling: the host sends a fresh snapshot on entry.
    stop = api.on('slot.statusChanged', ({ slot, status }) => {
      const row = settings.canonical?.slots.find((s) => s.number === slot)
      if (row) row.status = status
    })
    void api.request('slot.watchStatus', { enabled: true }).catch((e) => {
      if (active) error.value = String(e.message ?? e)
    })
  }, { immediate: true })
  onUnmounted(() => {
    active = false
    stop?.()
    if (started) void settingsClient()?.request('slot.watchStatus', { enabled: false }).catch(() => {})
  })
  return error
}

export const slotBehavior = (slot: SlotState) => slot.kind === 'permanent' ? slot.value : slot.effective
export const slotLabel = (slot: SlotState) => slot.kind === 'permanent' ? slot.value.name : slot.label
export function monitorLabel(monitor: MonitorRef): string {
  if (monitor.kind === 'cursor') return 'Под курсором'
  if (monitor.kind === 'number') return `Монитор ${monitor.number}`
  return `Некорректное значение: ${monitor.raw}`
}
export const edgeLabels = { left: 'Слева', right: 'Справа', top: 'Сверху', bottom: 'Снизу' }
export const statusLabels: Record<SlotStatus['state'], string> = {
  empty: 'Пусто', applicationNotRunning: 'Не запущено', available: 'Доступно',
  parked: 'Убрано', shown: 'На экране',
}
