// Канонический state приходит от AHK по четырём каналам: начальная
// загрузка, Save, slot.bind/slot.release и частичный отказ записи. Все
// они асинхронные, и без общего правила «кто главнее» поздний ответ
// одного канала затирает более свежий ответ другого. Здесь два правила,
// которые делают каналы совместимыми, и оба они чистые — их можно
// проверить без Vue и без моста.

import { slotDraftsFromState, type SlotDrafts } from './slotDraft'
import type { SettingsState, SlotNumber } from './protocol'

// Правило порядка. Каждый запрос за каноническим состоянием берёт номер
// ДО await; ответ применяется, только если этот номер новее последнего
// применённого. Полагаться на порядок доставки нельзя: у picker ответ
// уходит из таймера, а не из обработчика сообщения, и любая будущая
// операция, отвечающая не сразу, порядок ломает так же.
//
// Save и загрузка — отдельный случай: их снимок сделан ПОСЛЕ записи и
// потому авторитетен по построению. Он применяется всегда и заодно
// закрывает дорогу всем ответам, выданным до него.
export class CanonicalGate {
    private issued = 0
    private accepted = 0

    issue(): number {
        return ++this.issued
    }

    // Побочный канал: bind/release, state из ошибки частичной записи.
    acceptSide(ticket: number): boolean {
        if (ticket <= this.accepted) return false
        this.accepted = ticket
        return true
    }

    // Save/загрузка: применяется всегда, но двигает границу вперёд.
    acceptSave(ticket: number): boolean {
        this.accepted = Math.max(this.accepted, ticket)
        return true
    }
}

// Правило черновиков при замене canonical мимо Save.
//
// Черновик помнит baseKind — род, которым слот был в canonical, откуда
// черновик заведён. Сравнение с родом того же слота в новом снимке и
// отвечает, описывает ли черновик всё ещё этот слот:
//
//  - род в canonical не менялся -> черновик сохраняется, даже грязный, и
//    даже если человек уже переключил в нём kind: набранное не повод
//    стирать из-за привязки окна к соседнему слоту;
//  - род в canonical сменился   -> черновик описывает уже не тот слот и
//    заводится заново из нового снимка вместе с новым baseKind;
//  - успешный Save              -> сюда не приходит: там adopt, то есть
//    полная пересборка из применённого состояния.
export function reconcileSlotDrafts(drafts: SlotDrafts, next: SettingsState): SlotDrafts {
    const fresh = slotDraftsFromState(next)
    const out: SlotDrafts = {}
    for (const key of Object.keys(fresh)) {
        const n = Number(key) as SlotNumber
        const draft = drafts[n]
        out[n] = draft && draft.baseKind === fresh[n]!.baseKind ? draft : fresh[n]
    }
    return out
}
