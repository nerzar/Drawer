import { onUnmounted, ref, watch } from 'vue'
import { settings, settingsClient } from './settings'
import { t } from '../i18n'
import type { MonitorRef, SlotState, SlotStatus } from './protocol'
import type { SlotDraft } from './slotDraft'

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

export function isPendingDynamicConversion(slot: SlotState, draft?: SlotDraft): boolean {
  return slot.kind === 'permanent' && draft?.kind === 'dynamic'
}

export function isRuntimeDynamicBound(slot: SlotState): boolean {
  return slot.kind === 'dynamic' && slot.status.state !== 'empty'
}

export type HotkeyPresentation = { active: string; pending: string | null }

export function hotkeyPresentation(slot: SlotState, draft?: SlotDraft): HotkeyPresentation {
  const active = slot.kind === 'permanent' ? slot.value.hotkey : slot.hotkey
  const pending = draft && draft.hotkey !== active ? draft.hotkey : null
  return { active, pending }
}

// Чем строка списка подписана. У постоянного слота имя задал человек. У
// динамического имени нет вовсе — там стоит «Слот N», и пока слот занят,
// это худшая из возможных подписей: девять одинаковых строк. Поэтому
// занятый динамический слот подписывается приложением своего окна.
export function rowLabel(slot: SlotState): string {
  if (slot.kind === 'permanent') return slot.value.name
  const app = 'application' in slot.status ? slot.status.application : ''
  return app || slot.label
}

// Иконка окна слота, если она доехала. Пусто — форма покажет свой знак.
export function slotIcon(slot: SlotState): string {
  return ('icon' in slot.status && slot.status.icon) || ''
}
export function monitorLabel(monitor: MonitorRef): string {
  if (monitor.kind === 'cursor') return t('monitor.cursor')
  if (monitor.kind === 'number') return t('monitor.number', { n: monitor.number })
  return t('monitor.invalid', { raw: monitor.raw })
}

const EDGE_KEYS = { left: 'edge.left', right: 'edge.right', top: 'edge.top', bottom: 'edge.bottom' } as const

export function edgeLabel(edge: keyof typeof EDGE_KEYS): string {
  return t(EDGE_KEYS[edge])
}

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
      return { text: t('status.slot.empty'), dot: 'transparent', color: 'var(--text-3)' }
    case 'applicationNotRunning':
      return { text: t('status.slot.notRunning'), dot: IDLE, color: 'var(--text-3)' }
    case 'available':
      return { text: t('status.slot.available'), dot: BOUND, color: 'var(--text-2)' }
    case 'parked':
      return { text: t('status.slot.parked'), dot: BOUND, color: 'var(--text-2)' }
    case 'shown':
      return { text: t('status.slot.shown'), dot: BOUND, color: 'var(--text-2)' }
  }
}
