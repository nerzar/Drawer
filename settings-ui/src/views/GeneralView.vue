<script setup>
import { computed, ref } from 'vue'
import { settings } from '../bridge/settings'
import {
  ACCENT_PALETTE,
  ANIM_PRESETS,
  EDGE_OPTIONS,
  animPreset,
  applyAnimPreset,
} from '../bridge/general'

// Форма правит только черновик. Значения в нём — из canonical state
// AHK, и вернуться туда они могут единственным путём: Применить/ОК.
const d = computed(() => settings.draft)
const loaded = computed(() => settings.draft !== null)

// Что действует прямо сейчас. Меняется только из ответа AHK, поэтому
// расходится с полем ровно тогда, когда правка ещё не сохранена.
const applied = computed(() => settings.canonical?.general ?? null)

const bad = (path) => settings.field === path

const preset = computed({
  get: () => (settings.draft ? animPreset(settings.draft) : 'normal'),
  set: (v) => settings.draft && applyAnimPreset(settings.draft, v),
})
const customAnim = computed(() => preset.value === 'custom')

const accentCss = computed(() => '#' + (settings.draft?.accent ?? '2A2E35'))
const customColorInput = ref(null)

function pickAccent(hex) {
  if (settings.draft) settings.draft.accent = hex
}

function pickCustomAccent(event) {
  if (settings.draft) settings.draft.accent = event.target.value.slice(1).toUpperCase()
}

function triggerCustomColor() {
  customColorInput.value?.click()
}
</script>

<template>
  <div class="content">
    <h1 class="page-title">Общие настройки</h1>
    <p class="page-sub">Поведение, внешний вид и умолчания для динамических слотов.</p>

    <div v-if="!loaded" class="card empty">Настройки ещё не прочитаны.</div>

    <div v-else class="grid2">
      <div class="card">
        <h3>Поведение по умолчанию</h3>
        <p class="hint">
          Действует на динамические слоты — у постоянных свои значения в config.ini, отсюда их не
          поменять.
        </p>
        <div class="row">
          <label>Размер окна</label>
          <div class="field">
            <input
              class="num-sm"
              :class="{ 'field-bad': bad('general.dynamicDefaults.widthPercent') }"
              type="text"
              data-testid="widthPercent"
              v-model="d.widthPercent"
            />
            <span class="unit">% экрана</span>
          </div>
        </div>
        <div class="row">
          <label>Сторона выезда</label>
          <select class="dd" data-testid="edge" v-model="d.edge">
            <option v-for="o in EDGE_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
          </select>
        </div>
        <div class="row">
          <label>Монитор</label>
          <div class="field">
            <select
              class="dd"
              :class="{ narrow: d.monitorKind === 'number' }"
              data-testid="monitorKind"
              v-model="d.monitorKind"
            >
              <option value="cursor">Следовать за курсором</option>
              <option value="number">Номер монитора</option>
              <!-- Значение из файла, которого не бывает у контролов.
                   Пункт есть, пока его не заменили: подменить его на
                   cursor значило бы поменять настройку молча. -->
              <option v-if="d.monitorKind === 'invalid'" value="invalid">
                в файле: {{ d.monitorRaw }}
              </option>
            </select>
            <input
              v-if="d.monitorKind === 'number'"
              class="num-sm"
              :class="{ 'field-bad': bad('general.dynamicDefaults.monitor.number') }"
              type="text"
              data-testid="monitorNumber"
              v-model="d.monitorNumber"
            />
          </div>
        </div>
        <label class="check-row">
          <input type="checkbox" data-testid="activateOnShow" v-model="d.activateOnShow" />
          <span>Активировать окно при открытии</span>
        </label>
        <label class="check-row">
          <input type="checkbox" data-testid="hideOnBlur" v-model="d.hideOnBlur" />
          <span>Убирать окно, когда фокус ушёл в другое</span>
        </label>
      </div>

      <div class="card">
        <h3>Внешний вид</h3>
        <label class="check-row" style="margin-bottom: 14px">
          <input type="checkbox" data-testid="handlesEnabled" v-model="d.handlesEnabled" />
          <span>Кромки у края экрана</span>
        </label>

        <div class="divider"></div>

        <div class="row" style="margin-bottom: 10px">
          <label>Цвет акцента</label>
          <div class="field">
            <span class="unit">HEX</span>
            <input
              class="num-hex"
              type="text"
              data-testid="accent"
              maxlength="6"
              v-model="d.accent"
            />
          </div>
        </div>
        <div style="display: flex; align-items: center; gap: 16px">
          <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap; flex: 1">
            <button
              v-for="hex in ACCENT_PALETTE"
              :key="hex"
              class="swatch"
              type="button"
              :data-testid="'swatch-' + hex"
              :style="{ background: '#' + hex }"
              :aria-label="'Цвет #' + hex"
              :aria-pressed="hex.toLowerCase() === d.accent.toLowerCase()"
              @click="pickAccent(hex)"
            >
              <svg
                v-if="hex.toLowerCase() === d.accent.toLowerCase()"
                width="12"
                height="12"
                viewBox="0 0 24 24"
                fill="none"
                stroke="#fff"
                stroke-width="3"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </button>
            <label
              class="swatch-add"
              title="Свой цвет"
              aria-label="Свой цвет"
              tabindex="0"
              @keydown.enter.prevent="triggerCustomColor"
              @keydown.space.prevent="triggerCustomColor"
            >
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                <line x1="12" y1="5" x2="12" y2="19" />
                <line x1="5" y1="12" x2="19" y2="12" />
              </svg>
              <input
                ref="customColorInput"
                type="color"
                :value="accentCss"
                @input="pickCustomAccent"
                class="visually-hidden-color"
                aria-label="Выбрать свой цвет"
              />
            </label>
          </div>
          <div class="preview-box" aria-hidden="true">
            <div class="preview-handle" :style="{ background: accentCss }">
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#D6DAE2" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="9 6 15 12 9 18" />
              </svg>
            </div>
          </div>
        </div>
      </div>

      <div class="card">
        <h3>Анимация</h3>
        <p class="hint">
          Плавность — способ показа тех же двух чисел. «Своя» открывает их для правки.
        </p>
        <div class="row">
          <label>Плавность</label>
          <select class="dd" data-testid="animPreset" v-model="preset">
            <option value="none">Без анимации</option>
            <option v-for="o in ANIM_PRESETS" :key="o.id" :value="o.id">{{ o.label }}</option>
            <option value="custom">Своя</option>
          </select>
        </div>
        <div class="row">
          <label>Длительность (мс)</label>
          <div class="field">
            <input
              class="num-sm"
              :class="{ 'disabled-field': !customAnim }"
              type="text"
              data-testid="animMs"
              :disabled="!customAnim"
              v-model="d.animMs"
              @input="d.animCustom = true"
            />
          </div>
        </div>
        <div class="row">
          <label>Шагов</label>
          <div class="field">
            <input
              class="num-sm"
              :class="{ 'disabled-field': !customAnim }"
              type="text"
              data-testid="animSteps"
              :disabled="!customAnim"
              v-model="d.animSteps"
              @input="d.animCustom = true"
            />
          </div>
        </div>
      </div>

      <div class="card">
        <h3>Дополнительно</h3>
        <div class="row">
          <label>Проверка потери фокуса (мс)</label>
          <div class="field">
            <input
              class="num-sm"
              :class="{ 'field-bad': bad('general.blurCheckMs') }"
              type="text"
              data-testid="blurCheckMs"
              v-model="d.blurCheckMs"
            />
          </div>
        </div>
        <p class="hint" style="margin-top: 12px; margin-bottom: 0">
          Интервал опроса, используется для скрытия окна, когда фокус ушёл.
          <span v-if="applied" data-testid="blurApplied">
            Применено сейчас: {{ applied.blurCheckMs }} мс.
          </span>
        </p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.content {
  flex: 1;
  overflow-y: auto;
  padding: 30px 36px 24px;
}
.page-title {
  font-size: 21px;
  font-weight: 600;
  margin: 0 0 4px;
}
.page-sub {
  font-size: 13px;
  color: var(--text-2);
  margin: 0 0 24px;
}
.grid2 {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 18px;
  align-items: stretch;
}
.card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 20px;
  display: flex;
  flex-direction: column;
}
.card.empty {
  color: var(--text-2);
  font-size: 13px;
}
.card h3 {
  font-size: 13px;
  font-weight: 600;
  margin: 0 0 4px;
}
.card .hint {
  font-size: 12px;
  color: var(--text-2);
  line-height: 1.5;
  margin: 0 0 16px;
}
.row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 32px;
  margin-bottom: 10px;
  gap: 12px;
}
.row:last-child {
  margin-bottom: 0;
}
.row label {
  font-size: 13px;
  color: var(--text);
  flex: 0 0 auto;
}
.field {
  display: flex;
  align-items: center;
  gap: 8px;
}
input[type='text'],
select.dd {
  font: inherit;
  font-size: 13px;
  height: 30px;
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 0 10px;
  background: var(--field-bg);
  color: var(--text);
}
select.dd {
  appearance: none;
  -webkit-appearance: none;
  -moz-appearance: none;
  width: 188px;
  padding-right: 32px;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%239A9CA3' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 10px center;
  background-size: 15px 15px;
}
select.dd option {
  background-color: #1e2025;
  color: #ededef;
}
select.dd.narrow {
  width: 128px;
}
.num-sm {
  width: 52px;
  text-align: right;
}
.num-hex {
  width: 76px;
  text-transform: uppercase;
}
.unit {
  font-size: 12.5px;
  color: var(--text-2);
}
.check-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
  cursor: pointer;
  user-select: none;
}
.check-row:last-child {
  margin-bottom: 0;
}
.check-row input {
  width: 16px;
  height: 16px;
  accent-color: var(--accent-fg);
  cursor: pointer;
}
.check-row span {
  font-size: 13px;
}
.divider {
  height: 1px;
  background: var(--border);
  margin: 16px 0;
}
.swatch {
  width: 27px;
  height: 27px;
  border-radius: 999px;
  border: 1px solid var(--border-strong);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  cursor: pointer;
  outline: none;
  transition: transform 0.1s ease, border-color 0.15s ease;
}
.swatch:hover {
  border-color: rgba(255, 255, 255, 0.4);
  transform: scale(1.08);
}
.swatch:focus-visible {
  outline: 2px solid var(--accent-fg);
  outline-offset: 2px;
}
.swatch-add {
  width: 27px;
  height: 27px;
  border-radius: 999px;
  border: 1.5px dashed var(--border-strong);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-3);
  cursor: pointer;
  position: relative;
  outline: none;
  transition: border-color 0.15s ease, color 0.15s ease, transform 0.1s ease;
}
.swatch-add:hover {
  border-color: rgba(255, 255, 255, 0.4);
  color: var(--text-2);
  transform: scale(1.08);
}
.swatch-add:focus-visible,
.swatch-add:focus-within {
  outline: 2px solid var(--accent-fg);
  outline-offset: 2px;
  border-color: var(--accent-fg);
  color: var(--text-2);
}
.visually-hidden-color {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
  opacity: 0;
  pointer-events: none;
}
.preview-box {
  width: 88px;
  height: 108px;
  border-radius: 8px;
  background: #dee0e4;
  border: 1px solid var(--border);
  position: relative;
  overflow: hidden;
  flex: 0 0 auto;
}
.preview-handle {
  position: absolute;
  right: 0;
  top: 50%;
  transform: translateY(-50%);
  width: 20px;
  height: 34px;
  border-radius: 6px 0 0 6px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.disabled-field {
  opacity: 0.5;
}
.field-bad {
  border-color: #a04a45;
}
input[disabled] {
  opacity: 0.5;
}
</style>
