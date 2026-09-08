import type { MonitorDescriptor } from './protocol'
import type { MonitorKind } from './general'

export type MonitorSelectOption = {
  value: string
  label: string
  disabled?: boolean
}

export function formatMonitorLabel(m: MonitorDescriptor): string {
  return `Монитор ${m.number} — ${m.width}×${m.height}`
}

export function buildMonitorOptions(
  monitors: MonitorDescriptor[] = [],
  current: { monitorKind: MonitorKind; monitorNumber: string; monitorRaw?: string },
  cursorLabel = 'Следовать за курсором',
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
      label: `Монитор ${current.monitorNumber} (недоступен)`,
      disabled: true
    })
  }

  // Если в файле было невалидное значение
  if (current.monitorKind === 'invalid') {
    options.push({
      value: 'invalid',
      label: invalidLabel ?? (current.monitorRaw ? `Некорректное значение: ${current.monitorRaw} — выберите монитор` : 'Некорректное значение — выберите монитор'),
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
