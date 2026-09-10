import { t } from '../i18n'
import type { MonitorDescriptor } from './protocol'
import type { MonitorKind } from './general'

export type MonitorSelectOption = {
  value: string
  label: string
  disabled?: boolean
}

export function formatMonitorLabel(m: MonitorDescriptor): string {
  return t('monitor.label', { n: m.number, w: m.width, h: m.height })
}

export function buildMonitorOptions(
  monitors: MonitorDescriptor[] = [],
  current: { monitorKind: MonitorKind; monitorNumber: string; monitorRaw?: string },
  cursorLabel = t('monitor.cursorDefault'),
  invalidLabel?: string
): MonitorSelectOption[] {
  const options: MonitorSelectOption[] = [
    { value: 'cursor', label: cursorLabel }
  ]

  let currentFound = false
  for (const m of monitors) {
    if (current.monitorKind === 'number' && String(m.number) === String(current.monitorNumber)) {
      currentFound = true
    }
    options.push({
      value: String(m.number),
      label: formatMonitorLabel(m)
    })
  }

  // Если в файле был номер, но монитора с таким номером нет в списке
  if (current.monitorKind === 'number' && !currentFound) {
    options.push({
      value: String(current.monitorNumber),
      label: t('monitor.unavailable', { n: current.monitorNumber }),
      disabled: true
    })
  }

  // Если в файле было невалидное значение
  if (current.monitorKind === 'invalid') {
    options.push({
      value: 'invalid',
      label: invalidLabel ?? (current.monitorRaw ? t('monitor.invalidChoose', { raw: current.monitorRaw }) : t('monitor.invalidChooseGeneric')),
      disabled: true
    })
  }

  return options
}

export function currentMonitorValue(current: { monitorKind: MonitorKind; monitorNumber: string }): string {
  if (current.monitorKind === 'cursor') return 'cursor'
  if (current.monitorKind === 'invalid') return 'invalid'
  return String(current.monitorNumber)
}

export function setMonitorValue(
  target: { monitorKind: MonitorKind; monitorNumber: string },
  value: string
): void {
  if (value === 'cursor') {
    target.monitorKind = 'cursor'
  } else if (value === 'invalid') {
    target.monitorKind = 'invalid'
  } else {
    target.monitorKind = 'number'
    target.monitorNumber = String(value)
  }
}
