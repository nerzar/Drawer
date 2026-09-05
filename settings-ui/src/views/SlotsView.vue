<script setup>
import { computed, ref } from 'vue'
import { settings } from '../bridge/settings'
import { useSlotStatus, slotBehavior, slotLabel, monitorLabel, edgeLabels, statusLabels } from '../bridge/slots'

const selectedNumber = ref(1)
const slots = computed(() => settings.canonical?.slots ?? [])
const selectedSlot = computed(() => slots.value.find((s) => s.number === selectedNumber.value))
const behavior = computed(() => selectedSlot.value && slotBehavior(selectedSlot.value))
const watchError = useSlotStatus()
const draft = computed(() => settings.slotDrafts[selectedNumber.value])
const textFields = [
  { key: 'name', label: 'Имя' }, { key: 'executable', label: 'Файл (exe)' },
  { key: 'windowClass', label: 'Класс окна' }, { key: 'focusHotkey', label: 'Хоткей фокуса' },
  { key: 'widthPercent', label: 'Размер (%)' },
]
const bad = (key) => settings.field === `slots.${selectedNumber.value}.${key}`
</script>

<template>
  <div class="content">
    <h1 class="page-title">Слоты Drawer</h1>
    <p class="page-sub">Настройки постоянных слотов и состояние окон. Динамические слоты — только просмотр.</p>
    <p v-if="watchError" role="alert">Обновление статусов недоступно: {{ watchError }}</p>
    <p v-if="!settings.canonical">{{ settings.message || 'Читаем настройки…' }}</p>
    <div v-else class="split" data-testid="slots">
      <div class="list" aria-label="Слоты">
        <button v-for="slot in slots" :key="slot.number" class="slotrow"
          :data-testid="`slot-${slot.number}`" :data-status="slot.status.state"
          :aria-pressed="slot.number === selectedNumber"
          :style="{ background: slot.number === selectedNumber ? 'var(--accent-tint)' : 'transparent' }"
          @click="selectedNumber = slot.number">
          <div class="avatar" :class="{ 'avatar-empty': slot.kind === 'dynamic' }">{{ slot.number }}</div>
          <div style="flex: 1; min-width: 0">
            <div class="slotrow-name">{{ slotLabel(slot) }}</div>
            <div class="slotrow-meta">{{ edgeLabels[slotBehavior(slot).edge] }} · {{ monitorLabel(slotBehavior(slot).monitor) }} · {{ slotBehavior(slot).widthPercent }}%</div>
          </div>
          <div class="slotrow-right">
            <div class="status" :title="slot.status.windowTitle || ''">{{ statusLabels[slot.status.state] }}</div>
            <div class="pill">{{ slot.kind === 'permanent' ? 'Постоянный' : 'Динамический' }}</div>
          </div>
        </button>
      </div>
      <div v-if="selectedSlot" class="detail" data-testid="slot-detail">
        <div class="detail-head"><h2>Слот {{ selectedSlot.number }}</h2></div>
        <div class="detail-divider"></div>
        <div class="detail-row"><div class="l">Имя</div><div class="v">{{ slotLabel(selectedSlot) }}</div></div>
        <div class="detail-row"><div class="l">Состояние</div><div class="v">{{ statusLabels[selectedSlot.status.state] }}</div></div>
        <div class="detail-row"><div class="l">Заголовок окна</div><div class="v" data-testid="slot-title">{{ selectedSlot.status.windowTitle || '—' }}</div></div>
        <fieldset v-if="selectedSlot.kind === 'permanent' && draft" class="slot-editor" :disabled="settings.status === 'saving'">
          <div v-for="field in textFields" :key="field.key" class="row">
            <label :for="`slot-${field.key}`">{{ field.label }}</label>
            <input :id="`slot-${field.key}`" :data-testid="`edit-${field.key}`" type="text"
              :class="{ 'field-bad': bad(field.key) }" :aria-invalid="bad(field.key)" v-model="draft[field.key]" />
          </div>
          <div class="row">
            <label for="slot-monitor">Монитор</label>
            <select id="slot-monitor" class="dd" data-testid="edit-monitorKind" v-model="draft.monitorKind" :class="{ 'field-bad': bad('monitor') }">
              <option value="cursor">Под курсором</option><option value="number">По номеру</option>
              <option v-if="draft.monitorKind === 'invalid'" value="invalid">Некорректно: {{ draft.monitorRaw }}</option>
            </select>
          </div>
          <div v-if="draft.monitorKind === 'number'" class="row">
            <label for="slot-monitor-number">Номер монитора</label>
            <input id="slot-monitor-number" type="text" data-testid="edit-monitorNumber" v-model="draft.monitorNumber" :class="{ 'field-bad': bad('monitor.number') }" />
          </div>
          <div class="row">
            <label for="slot-edge">Край</label>
            <select id="slot-edge" class="dd" data-testid="edit-edge" v-model="draft.edge" :class="{ 'field-bad': bad('edge') }">
              <option v-for="(label, edge) in edgeLabels" :key="edge" :value="edge">{{ label }}</option>
            </select>
          </div>
          <label class="check-row"><input type="checkbox" data-testid="edit-activateOnShow" v-model="draft.activateOnShow" />Активировать при выезде</label>
          <label class="check-row"><input type="checkbox" data-testid="edit-hideOnBlur" v-model="draft.hideOnBlur" />Убирать при потере фокуса</label>
          <p class="page-sub">Хоткей фокуса применяется после перезапуска.</p>
        </fieldset>
        <template v-else>
        <div class="detail-row"><div class="l">Монитор</div><div class="v">{{ monitorLabel(behavior.monitor) }}</div></div>
        <div class="detail-row"><div class="l">Край</div><div class="v">{{ edgeLabels[behavior.edge] }}</div></div>
        <div class="detail-row"><div class="l">Размер (%)</div><div class="v" data-testid="slot-width">{{ behavior.widthPercent }}</div></div>
        <div class="detail-row"><div class="l">Активировать при выезде</div><div class="v">{{ behavior.activateOnShow ? 'Да' : 'Нет' }}</div></div>
        <div class="detail-row"><div class="l">Убирать при потере фокуса</div><div class="v">{{ behavior.hideOnBlur ? 'Да' : 'Нет' }}</div></div>
        </template>
        <p v-if="settings.bad" role="alert">{{ settings.message }}</p>
        <div class="free-note">{{ selectedSlot.kind === 'dynamic' ? 'Показаны действующие параметры этого динамического слота, включая индивидуальные настройки.' : 'Применить и ОК сохраняют настройки General и постоянных слотов. Список слева показывает применённые значения.' }}</div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.slot-editor { border: 0; padding: 16px 0 0; margin: 0; min-width: 0; }
.field-bad { outline: 1px solid #e2857f; }
.content {
  flex: 1;
  padding: 26px 36px 20px;
  display: flex;
  flex-direction: column;
  min-height: 0;
}
.page-title {
  font-size: 21px;
  font-weight: 600;
  margin: 0 0 4px;
}
.page-sub {
  font-size: 13px;
  color: var(--text-2);
  margin: 0 0 16px;
}
.split {
  flex: 1;
  display: flex;
  gap: 18px;
  min-height: 0;
}
.list {
  width: 358px;
  flex: 0 0 auto;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--bg-card);
  overflow: hidden;
  overflow-y: auto;
}
.slotrow {
  width: 100%;
  font: inherit;
  color: var(--text);
  text-align: left;
  border: 0;
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 8px 13px;
  border-bottom: 1px solid var(--border);
  cursor: default;
}
.slotrow:last-child {
  border-bottom: none;
}
.avatar {
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: var(--neutral-bg);
  color: var(--text-2);
  font-size: 12px;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 0 0 auto;
}
.avatar-empty {
  background: transparent;
  border: 1.5px dashed var(--border-strong);
}
.slotrow-name {
  font-size: 12.5px;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.slotrow-meta {
  font-size: 11px;
  color: var(--text-3);
  margin-top: 1px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.slotrow-right {
  flex: 0 0 auto;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 4px;
}
.status {
  font-size: 10.5px;
  display: flex;
  align-items: center;
  gap: 5px;
}
.dot {
  width: 6px;
  height: 6px;
  border-radius: 999px;
  flex: 0 0 auto;
}
.pill {
  font-size: 10px;
  font-weight: 600;
  padding: 2px 7px;
  border-radius: 999px;
  white-space: nowrap;
}
.detail {
  flex: 1;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--bg-card);
  padding: 18px 22px;
  overflow: hidden;
  overflow-y: auto;
  min-width: 0;
}
.detail-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 4px;
}
.detail-head h2 {
  font-size: 16px;
  font-weight: 600;
  margin: 0;
}
.detail-divider {
  height: 1px;
  background: var(--border);
  margin: 12px 0 14px;
}
.row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 30px;
  margin-bottom: 8px;
  gap: 12px;
}
.row label {
  font-size: 12.5px;
  color: var(--text);
  flex: 0 0 120px;
}
.field {
  display: flex;
  align-items: center;
  gap: 6px;
}
input[type='text'],
select.dd {
  font: inherit;
  font-size: 12.5px;
  height: 28px;
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 0 9px;
  background: var(--field-bg);
  color: var(--text);
}
select.dd {
  appearance: none;
  -webkit-appearance: none;
  -moz-appearance: none;
  width: 212px;
  padding-right: 32px;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%239A9CA3' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 10px center;
  background-size: 15px 15px;
}
.in-name {
  width: 212px;
}
.in-exe {
  width: 118px;
}
.btn-icon {
  width: 28px;
  height: 28px;
  padding: 0;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  border: 1px solid var(--border-strong);
  background: transparent;
  color: var(--text-2);
}
.btn-icon:hover {
  background: rgba(255, 255, 255, 0.05);
}
.num-sm {
  width: 52px;
  text-align: right;
}
.info-ico {
  position: relative;
  width: 20px;
  height: 20px;
  border-radius: 999px;
  border: 1px solid var(--border-strong);
  color: var(--text-3);
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
}
.info-ico .tip {
  position: absolute;
  left: 50%;
  top: 26px;
  transform: translate(-50%, -4px);
  width: 230px;
  background: #26282f;
  border: 1px solid var(--border-strong);
  border-radius: 8px;
  padding: 10px 12px;
  font-size: 11px;
  line-height: 1.55;
  color: var(--text-2);
  box-shadow: 0 10px 26px rgba(0, 0, 0, 0.45);
  opacity: 0;
  visibility: hidden;
  transition: opacity 0.15s ease, transform 0.15s ease;
  z-index: 5;
}
.info-ico:hover .tip,
.info-ico:focus .tip {
  opacity: 1;
  visibility: visible;
  transform: translate(-50%, 0);
}
.info-ico .tip code {
  font-family: 'Cascadia Code', Consolas, monospace;
  color: var(--text);
}
.check-row {
  display: flex;
  align-items: center;
  gap: 9px;
  margin-bottom: 8px;
}
.check-row input {
  width: 15px;
  height: 15px;
  accent-color: var(--accent-fg);
}
.check-row span {
  font-size: 12.5px;
}
.hotkey-cap {
  font-size: 10.5px;
  color: var(--text-3);
  margin: -3px 0 8px 120px;
}
.detail-row {
  display: flex;
  align-items: baseline;
  padding: 6px 0;
  font-size: 12.5px;
  border-bottom: 1px dashed var(--border);
}
.detail-row .l {
  width: 160px;
  color: var(--text-2);
  flex: 0 0 auto;
  max-width: 48%;
}
.detail-row .v {
  flex: 1;
  min-width: 0;
  overflow-wrap: anywhere;
}
.detail-row .s {
  font-size: 10.5px;
  color: var(--text-3);
  flex: 0 0 auto;
  padding-left: 10px;
}
.free-note {
  display: flex;
  gap: 9px;
  background: var(--accent-tint);
  border-radius: 8px;
  padding: 11px 13px;
  margin-top: 12px;
  font-size: 11.5px;
  color: var(--text);
  line-height: 1.5;
}
.btn-primary-sm {
  font: inherit;
  font-size: 12px;
  height: 29px;
  padding: 0 13px;
  border-radius: 6px;
  border: 1px solid transparent;
  background: var(--accent-fg);
  color: #14151a;
  font-weight: 600;
}
.btn-danger-hd {
  font: inherit;
  font-size: 12.5px;
  height: 30px;
  padding: 0 14px;
  border-radius: 6px;
  border: 1px solid rgba(229, 135, 138, 0.4);
  background: transparent;
  color: #e5878a;
}
.btn-danger-hd:hover {
  background: rgba(229, 135, 138, 0.08);
}
</style>
