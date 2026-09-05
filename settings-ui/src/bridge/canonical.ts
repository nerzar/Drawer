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
// Черновик слота существует ровно у постоянных слотов — так его заводит
// slotDraftsFromState, и это единственный способ его появления. Поэтому
// сам факт наличия черновика говорит, каким слот был, а наличие слота в
// новом снимке — каким он стал:
//
//  - слот остался постоянным  -> черновик сохраняется, даже грязный:
//    человек его набрал, и замена canonical по чужому поводу (привязка
//    окна, частичный отказ) не повод стирать несохранённое;
//  - слот сменил род          -> старый черновик описывает уже не тот
//    слот и выбрасывается: постоянный стал динамическим — черновика
//    нет вовсе, динамический стал постоянным — черновик заводится из
//    canonical;
//  - успешный Save            -> сюда не приходит: там adopt, то есть
//    полная пересборка из применённого состояния.
export function reconcileSlotDrafts(drafts: SlotDrafts, next: SettingsState): SlotDrafts {
    const fresh = slotDraftsFromState(next)
    const out: SlotDrafts = {}
    for (const key of Object.keys(fresh)) {
        const n = Number(key) as SlotNumber
        out[n] = drafts[n] ?? fresh[n]
    }
    return out
}
