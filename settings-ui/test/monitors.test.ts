import assert from 'node:assert/strict'
import { test } from 'node:test'

import {
  formatMonitorLabel,
  buildMonitorOptions,
  currentMonitorValue,
  setMonitorValue,
} from '../src/bridge/monitors'
import type { MonitorDescriptor } from '../src/bridge/protocol'

test('monitors bridge helper: formats monitor labels with dimensions', () => {
  const monitors: MonitorDescriptor[] = [
    { number: 1, width: 1920, height: 1080 },
    { number: 2, width: 2560, height: 1440 },
  ]
  assert.equal(formatMonitorLabel(monitors[0]), 'Монитор 1 — 1920×1080')
  assert.equal(formatMonitorLabel(monitors[1]), 'Монитор 2 — 2560×1440')
})

test('monitors bridge helper: builds monitor options including cursor and available monitors', () => {
  const monitors: MonitorDescriptor[] = [
    { number: 1, width: 1920, height: 1080 },
    { number: 2, width: 2560, height: 1440 },
  ]
  const options = buildMonitorOptions(monitors, { monitorKind: 'cursor', monitorNumber: '1' })
  assert.deepEqual(options, [
    { value: 'cursor', label: 'Следовать за курсором' },
    { value: '1', label: 'Монитор 1 — 1920×1080' },
    { value: '2', label: 'Монитор 2 — 2560×1440' },
  ])
})

test('monitors bridge helper: preserves unavailable monitor number as disabled option without silent mutation', () => {
  const monitors: MonitorDescriptor[] = [
    { number: 1, width: 1920, height: 1080 },
    { number: 2, width: 2560, height: 1440 },
  ]
  const options = buildMonitorOptions(monitors, { monitorKind: 'number', monitorNumber: '3' })
  assert.deepEqual(options, [
    { value: 'cursor', label: 'Следовать за курсором' },
    { value: '1', label: 'Монитор 1 — 1920×1080' },
    { value: '2', label: 'Монитор 2 — 2560×1440' },
    { value: '3', label: 'Монитор 3 (недоступен)', disabled: true },
  ])
})

test('monitors bridge helper: handles invalid monitor value gracefully', () => {
  const monitors: MonitorDescriptor[] = [
    { number: 1, width: 1920, height: 1080 }
  ]
  const options = buildMonitorOptions(monitors, { monitorKind: 'invalid', monitorNumber: '1', monitorRaw: 'abc' })
  assert.deepEqual(options, [
    { value: 'cursor', label: 'Следовать за курсором' },
    { value: '1', label: 'Монитор 1 — 1920×1080' },
    { value: 'invalid', label: 'Некорректное значение: abc — выберите монитор', disabled: true },
  ])
})

test('monitors bridge helper: extracts currentMonitorValue correctly', () => {
  assert.equal(currentMonitorValue({ monitorKind: 'cursor', monitorNumber: '1' }), 'cursor')
  assert.equal(currentMonitorValue({ monitorKind: 'number', monitorNumber: '2' }), '2')
  assert.equal(currentMonitorValue({ monitorKind: 'invalid', monitorNumber: '1' }), 'invalid')
})

test('monitors bridge helper: sets monitor value correctly on target draft', () => {
  const draft = { monitorKind: 'cursor' as const, monitorNumber: '1' }
  setMonitorValue(draft, '2')
  assert.equal(draft.monitorKind, 'number')
  assert.equal(draft.monitorNumber, '2')

  setMonitorValue(draft, 'cursor')
  assert.equal(draft.monitorKind, 'cursor')
  assert.equal(draft.monitorNumber, '2')
})
