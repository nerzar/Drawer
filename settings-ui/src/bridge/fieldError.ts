// Куда ведёт адрес поля из structured-ошибки.
//
// AHK отвечает на неудачный Save парой «сообщение + field», где field —
// путь вида «general.blurCheckMs» или «slots.3.executable». Путь этот
// адрес, а не текст: показать его человеку значит попросить искать
// контрол глазами. Здесь путь превращается в то, что форме нужно знать:
// на какой вкладке контрол, какого слота он и как называется.
//
// Функция чистая и проверяется без Vue: test/fieldError.test.ts.

import type { SlotNumber } from './protocol'

export type FieldTarget =
  | { tab: 'general'; slot: 0; control: string }
  // control пуст, когда backend знает только слот: границы значений он
  // проверяет своими сообщениями, и не у каждого из них есть поле.
  | { tab: 'slots'; slot: SlotNumber; control: string }

const SLOT_PATH = /^slots\.([1-9])(?:\.(.+))?$/

export function fieldTarget(field: string): FieldTarget | null {
  if (!field) return null
  const slot = SLOT_PATH.exec(field)
  if (slot) return { tab: 'slots', slot: Number(slot[1]) as SlotNumber, control: slot[2] ?? '' }
  if (field.startsWith('general.')) return { tab: 'general', slot: 0, control: field }
  return null
}
