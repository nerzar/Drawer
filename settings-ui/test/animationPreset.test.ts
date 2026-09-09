// Проверки поведения пресета анимации «Своя» (TASK G04).
//
// Запуск: npm test.

import assert from 'node:assert/strict'
import { test } from 'node:test'
import { computed, reactive } from 'vue'

import {
  ANIM_PRESETS,
  animPreset,
  applyAnimPreset,
  draftFromState,
  draftToWire,
  isCustomAnim,
  type GeneralDraft,
} from '../src/bridge/general'
import type { GeneralSettings } from '../src/bridge/protocol'

function makeGeneralSettings(durationMs = 167, steps = 14): GeneralSettings {
  return {
    dynamicDefaults: {
      monitor: { kind: 'cursor' },
      edge: 'right',
      widthPercent: 70,
      activateOnShow: true,
      hideOnBlur: true,
    },
    handlesEnabled: true,
    animation: { style: 'dwmSlideFade', durationMs, steps },
    blurCheckMs: 250,
    accent: '2A2E35',
  }
}

test('выбор «Своя» при совпадающем пресете сразу делает пресет кастомным и не откатывается', () => {
  const draft = draftFromState(makeGeneralSettings(167, 14))
  assert.equal(animPreset(draft), 'normal')

  applyAnimPreset(draft, 'custom')

  assert.equal(animPreset(draft), 'custom', 'пресет не должен откатываться к normal до ввода')
  assert.equal(draft.animMs, '167', 'длительность не должна самопроизвольно меняться')
  assert.equal(draft.animSteps, '14', 'шаги не должны самопроизвольно меняться')
  assert.equal(draft.animCustom, true)
})

test('выбор «Своя» при пресетах fast, smooth и none сохраняет текущие числа и активирует custom', () => {
  for (const preset of ANIM_PRESETS) {
    const draft = draftFromState(makeGeneralSettings(preset.ms, preset.steps))
    assert.equal(animPreset(draft), preset.id)

    applyAnimPreset(draft, 'custom')
    assert.equal(animPreset(draft), 'custom')
    assert.equal(draft.animMs, String(preset.ms))
    assert.equal(draft.animSteps, String(preset.steps))
  }

  const noneDraft = draftFromState(makeGeneralSettings(167, 0))
  assert.equal(animPreset(noneDraft), 'none')

  applyAnimPreset(noneDraft, 'custom')
  assert.equal(animPreset(noneDraft), 'custom')
  assert.equal(noneDraft.animMs, '167')
  assert.equal(noneDraft.animSteps, '0')
})

test('во время текущего unsaved edit-session явный выбор «Своя» не сбрасывается даже при совпадении чисел с пресетом', () => {
  const draft = draftFromState(makeGeneralSettings(167, 14))
  applyAnimPreset(draft, 'custom')

  // Пользователь в режиме «Своя» вводит числа, случайно совпадающие с fast (83 / 8)
  draft.animMs = '83'
  draft.animSteps = '8'
  assert.equal(animPreset(draft), 'custom', 'во время редактирования пресет не должен перескакивать на fast')

  // Пользователь возвращает значения к 167 / 14
  draft.animMs = '167'
  draft.animSteps = '14'
  assert.equal(animPreset(draft), 'custom', 'во время редактирования пресет не должен перескакивать на normal')
})

test('ручная правка уходит в wire DTO через существующий save path', () => {
    const draft = draftFromState(makeGeneralSettings(167, 14))
  draft.animationStyle = 'dwmSlideFade'
  applyAnimPreset(draft, 'custom')
  draft.animMs = '220'
  draft.animSteps = '18'

  const wire = draftToWire(draft)
  assert.deepEqual(wire.animation, { style: 'dwmSlideFade', durationMs: 220, steps: 18 })
  // Проверяем, что animCustom не протекает в wire DTO
  assert.equal('animCustom' in (wire as unknown as Record<string, unknown>), false)
})

test('после canonical response кастомные значения отображаются как «Своя»', () => {
  const canonicalAfterSave = makeGeneralSettings(220, 18)
  const draft = draftFromState(canonicalAfterSave)

  assert.equal(draft.animMs, '220')
  assert.equal(draft.animSteps, '18')
  assert.equal(animPreset(draft), 'custom')
  assert.equal(draft.animCustom, true)
})

test('если сохранённая пара случайно совпадает с известным пресетом, canonical state после reload отображается как этот пресет', () => {
  // Пользователь выбрал «Своя», но сохранил пару 167 / 14
  const canonicalAfterReload = makeGeneralSettings(167, 14)
  const reloadedDraft = draftFromState(canonicalAfterReload)

  assert.equal(animPreset(reloadedDraft), 'normal')
  assert.equal(reloadedDraft.animCustom, false)
})

test('переключение из «Своя» в стандартный пресет или none отключает custom и обновляет значения', () => {
  const draft = draftFromState(makeGeneralSettings(220, 18))
  assert.equal(animPreset(draft), 'custom')

  applyAnimPreset(draft, 'fast')
  assert.equal(animPreset(draft), 'fast')
  assert.equal(draft.animMs, '83')
  assert.equal(draft.animSteps, '8')
  assert.equal(draft.animCustom, false)

  applyAnimPreset(draft, 'custom')
  assert.equal(animPreset(draft), 'custom')

  applyAnimPreset(draft, 'none')
  assert.equal(animPreset(draft), 'none')
  assert.equal(draft.animSteps, '0')
  assert.equal(draft.animCustom, false)
})

test('реактивная связка GeneralView (preset и customAnim computed) делает поля редактируемыми сразу при выборе «Своя»', () => {
  const draft = reactive(draftFromState(makeGeneralSettings(167, 14)))
  const preset = computed({
    get: () => animPreset(draft),
    set: (v) => applyAnimPreset(draft, v),
  })
  const customAnim = computed(() => preset.value === 'custom')

  // Изначально обычный пресет — поля заблокированы
  assert.equal(preset.value, 'normal')
  assert.equal(customAnim.value, false)

  // Пользователь выбирает «Своя»
  preset.value = 'custom'

  // Пресет стал 'custom', поля разблокированы сразу
  assert.equal(preset.value, 'custom')
  assert.equal(customAnim.value, true)
  assert.equal(draft.animMs, '167')
  assert.equal(draft.animSteps, '14')

  // Пользователь вводит новые значения
  draft.animMs = '180'
  draft.animSteps = '16'
  assert.equal(preset.value, 'custom')
  assert.equal(customAnim.value, true)
})
