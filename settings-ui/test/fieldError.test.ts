// Разбор адреса поля из structured-ошибки: src/bridge/fieldError.ts.
// Функция чистая, поэтому проверяется без Vue, без моста и без AHK.
//
// Запуск: npm test.

import assert from 'node:assert/strict'
import { test } from 'node:test'

import { fieldTarget } from '../src/bridge/fieldError'

test('поле слота ведёт к слоту и контролу', () => {
  assert.deepEqual(fieldTarget('slots.3.executable'), {
    tab: 'slots', slot: 3, control: 'executable',
  })
})

test('вложенный контрол доезжает целиком', () => {
  assert.deepEqual(fieldTarget('slots.7.monitor.number'), {
    tab: 'slots', slot: 7, control: 'monitor.number',
  })
})

test('адрес без контрола ведёт к слоту: подсвечивать нечего', () => {
  assert.deepEqual(fieldTarget('slots.2'), { tab: 'slots', slot: 2, control: '' })
})

test('поле General ведёт на свою вкладку полным путём', () => {
  assert.deepEqual(fieldTarget('general.blurCheckMs'), {
    tab: 'general', slot: 0, control: 'general.blurCheckMs',
  })
})

test('пустое поле никуда не ведёт', () => {
  assert.equal(fieldTarget(''), null)
})

test('слот вне 1…9 — не адрес', () => {
  assert.equal(fieldTarget('slots.0.name'), null)
  assert.equal(fieldTarget('slots.12.name'), null)
})

test('незнакомый корень не переключает вкладку', () => {
  assert.equal(fieldTarget('draft.general.edge'), null)
  assert.equal(fieldTarget('slotEdits'), null)
  assert.equal(fieldTarget('generally.speaking'), null)
})
