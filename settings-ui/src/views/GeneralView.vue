<script setup>
import { computed } from 'vue'
import { state, EDGE_OPTIONS, MONITOR_OPTIONS, ANIM_OPTIONS } from '../mock/state'

const g = state.general

const animPreset = computed(() => ANIM_OPTIONS.find((o) => o.value === g.animEasing) ?? ANIM_OPTIONS[1])

function pickAccent(hex) {
  state.accent = hex
}

function pickCustomAccent(event) {
  state.accent = event.target.value
}
</script>

<template>
  <div class="content">
    <h1 class="page-title">Общие настройки</h1>
    <p class="page-sub">Поведение, внешний вид и умолчания для динамических слотов.</p>

    <div class="grid2">
      <div class="card">
        <h3>Поведение по умолчанию</h3>
        <p class="hint">
          Действует на динамические слоты — у постоянных свои значения в config.ini, отсюда их не
          поменять.
        </p>
        <div class="row">
          <label>Размер окна (% экрана)</label>
          <div class="field"><input class="num-sm" type="text" v-model="g.sizePercent" /></div>
        </div>
        <div class="row">
          <label>Сторона выезда</label>
          <select class="dd" v-model="g.edge">
            <option v-for="o in EDGE_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
          </select>
        </div>
        <div class="row">
          <label>Монитор</label>
          <select class="dd" v-model="g.monitor">
            <option v-for="o in MONITOR_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
          </select>
        </div>
        <div class="check-row">
          <input type="checkbox" v-model="g.activateOnShow" />
          <span>Активировать окно при открытии</span>
        </div>
        <div class="check-row">
          <input type="checkbox" v-model="g.hideOnBlur" />
          <span>Убирать окно, когда фокус ушёл в другое</span>
        </div>
      </div>

      <div class="card">
        <h3>Внешний вид</h3>
        <div class="check-row" style="margin-bottom: 14px">
          <input type="checkbox" v-model="g.handles" />
          <span>Кромки у края экрана</span>
        </div>

        <div class="row">
          <label>Размер кромки (px)</label>
          <div class="field">
            <input class="num-sm" type="text" v-model="g.handleWidth" />
            <span class="unit">×</span>
            <input class="num-sm" type="text" v-model="g.handleHeight" />
          </div>
        </div>
        <div class="row">
          <label>Отступ между кромками (px)</label>
          <div class="field"><input class="num-sm" type="text" v-model="g.handleGap" /></div>
        </div>

        <div class="divider"></div>

        <div class="row" style="margin-bottom: 10px">
          <label>Цвет акцента</label>
        </div>
        <div style="display: flex; align-items: center; gap: 16px">
          <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap; flex: 1">
            <button
              v-for="hex in state.accentPalette"
              :key="hex"
              class="swatch"
              type="button"
              :style="{ background: hex }"
              :aria-label="hex"
              @click="pickAccent(hex)"
            >
              <svg
                v-if="hex.toLowerCase() === state.accent.toLowerCase()"
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
            <label class="swatch-add" title="Свой цвет">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                <line x1="12" y1="5" x2="12" y2="19" />
                <line x1="5" y1="12" x2="19" y2="12" />
              </svg>
              <input type="color" :value="state.accent" @input="pickCustomAccent" hidden />
            </label>
          </div>
          <div class="preview-box">
            <div class="preview-handle" :style="{ background: state.accent }">
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#D6DAE2" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="9 6 15 12 9 18" />
              </svg>
            </div>
          </div>
        </div>
      </div>

      <div class="card">
        <h3>Анимация</h3>
        <div class="row">
          <label>Плавность</label>
          <select class="dd" v-model="g.animEasing">
            <option v-for="o in ANIM_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
          </select>
        </div>
        <div class="row">
          <label>Длительность (мс)</label>
          <div class="field"><input class="num-sm disabled-field" type="text" :value="animPreset.ms" disabled /></div>
        </div>
        <div class="row">
          <label>Шагов</label>
          <div class="field"><input class="num-sm disabled-field" type="text" :value="animPreset.steps" disabled /></div>
        </div>
      </div>

      <div class="card">
        <h3>Дополнительно</h3>
        <div class="row">
          <label>Проверка потери фокуса (мс)</label>
          <div class="field"><input class="num-sm" type="text" v-model="g.blurMs" /></div>
        </div>
        <p class="hint" style="margin-top: 12px; margin-bottom: 0">
          Интервал опроса, используется для скрытия окна, когда фокус ушёл.
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
.num-sm {
  width: 52px;
  text-align: right;
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
}
.check-row:last-child {
  margin-bottom: 0;
}
.check-row input {
  width: 16px;
  height: 16px;
  accent-color: var(--accent-fg);
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
  cursor: default;
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
  cursor: default;
  position: relative;
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
</style>
