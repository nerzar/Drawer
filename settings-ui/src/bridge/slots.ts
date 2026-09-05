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

// Как показать состояние слота: текст, точка и её цвет — ровно три
// вещи, которыми состояние показано в дизайне. Состояний пять, а в
// макете их было два: «запущено» и «не запущено». Три остальных — тот
// же факт «окно есть», только точнее, поэтому точка у них одна и та же
// зелёная, а различает их подпись.
export type StatusView = { text: string; dot: string; color: string }

const BOUND = '#3DAE68'
const IDLE = 'rgba(255,255,255,.2)'

export function statusFor(status: SlotStatus): StatusView {
  switch (status.state) {
    case 'empty':
      return { text: 'пусто', dot: 'transparent', color: 'var(--text-3)' }
    case 'applicationNotRunning':
      return { text: 'не запущено', dot: IDLE, color: 'var(--text-3)' }
    case 'available':
      return { text: 'запущено', dot: BOUND, color: 'var(--text-2)' }
    case 'parked':
      return { text: 'убрано', dot: BOUND, color: 'var(--text-2)' }
    case 'shown':
      return { text: 'на экране', dot: BOUND, color: 'var(--text-2)' }
  }
}
