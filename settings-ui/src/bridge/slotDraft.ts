import { monitorToWire, num, type MonitorKind } from './general'
import type { PermanentSlotValue, SettingsState, SlotEdit, SlotNumber } from './protocol'

export type PermanentDraft = Omit<PermanentSlotValue, 'monitor' | 'widthPercent'> & {
  widthPercent: string
  monitorKind: MonitorKind
  monitorNumber: string
  monitorRaw: string
}
export type SlotDrafts = Partial<Record<SlotNumber, PermanentDraft>>

export function slotDraftsFromState(state: SettingsState): SlotDrafts {
  const drafts: SlotDrafts = {}
  for (const slot of state.slots) {
    if (slot.kind !== 'permanent') continue
    const { monitor, widthPercent, ...fields } = slot.value
    drafts[slot.number] = {
      ...fields, widthPercent: String(widthPercent), monitorKind: monitor.kind,
      monitorNumber: monitor.kind === 'number' ? String(monitor.number) : '1',
      monitorRaw: monitor.kind === 'invalid' ? monitor.raw : '',
    }
  }
  return drafts
}

export function slotEditsToWire(drafts: SlotDrafts, state: SettingsState): SlotEdit[] {
  const edits: SlotEdit[] = []
  for (const slot of state.slots) {
    const draft = drafts[slot.number]
    if (slot.kind !== 'permanent' || !draft) continue
    const { monitorKind, monitorNumber, monitorRaw, widthPercent, ...fields } = draft
    const value: PermanentSlotValue = {
      ...fields, widthPercent: num(widthPercent),
      monitor: monitorToWire({ monitorKind, monitorNumber, monitorRaw }),
    }
    // Compare only config fields, never the live status attached to the row.
    if (Object.keys(value).some((key) => {
      const k = key as keyof PermanentSlotValue
      return JSON.stringify(value[k]) !== JSON.stringify(slot.value[k])
    })) edits.push({ number: slot.number, kind: 'permanent', value })
  }
  return edits
}
