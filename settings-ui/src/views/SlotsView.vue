<script setup>
import { computed } from 'vue'
import { state, EDGE_OPTIONS, MONITOR_OPTIONS } from '../mock/state'
import { bridge } from '../mock/bridge'

const selectedSlot = computed(() => state.slots.find((s) => s.n === state.selectedSlot))

function selectSlot(n) {
  state.selectedSlot = n
}

function makeDynamic() {
  const slot = selectedSlot.value
  slot.kind = 'dyn'
  slot.name = ''
  slot.exe = ''
  slot.cls = ''
  slot.icon = ''
  slot.running = false
}

function makePermanent() {
  const slot = selectedSlot.value
  slot.kind = 'perm'
  slot.name = slot.name || `Слот ${slot.n}`
}

function statusFor(slot) {
  if (slot.kind !== 'perm') return { text: 'пусто', dot: 'transparent', color: 'var(--text-3)' }
  if (slot.running) return { text: 'запущено', dot: '#3DAE68', color: 'var(--text-2)' }
  return { text: 'не запущено', dot: 'rgba(255,255,255,.2)', color: 'var(--text-3)' }
}
</script>

<template>
  <div class="content">
    <h1 class="page-title">Слоты Drawer</h1>
    <p class="page-sub">Настройте слоты для приложений и горячие клавиши.</p>

    <div class="split">
      <div class="list">
        <div
          v-for="slot in state.slots"
          :key="slot.n"
          class="slotrow"
          :style="{ background: slot.n === state.selectedSlot ? 'var(--accent-tint)' : 'transparent' }"
          @click="selectSlot(slot.n)"
        >
          <div class="avatar" :class="{ 'avatar-empty': slot.kind !== 'perm' }">
            <svg v-if="slot.icon === 'steam'" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
              <rect x="3" y="8" width="18" height="9" rx="4" />
              <line x1="7" y1="11" x2="7" y2="14" />
              <line x1="5.5" y1="12.5" x2="8.5" y2="12.5" />
              <circle cx="16" cy="11.3" r=".9" fill="currentColor" stroke="none" />
              <circle cx="18.2" cy="13.5" r=".9" fill="currentColor" stroke="none" />
            </svg>
            <svg v-else-if="slot.icon === 'cloud'" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
              <path d="M7 18a4 4 0 0 1-.5-7.97A5 5 0 0 1 16.9 9.01 4.5 4.5 0 0 1 16.5 18H7z" />
            </svg>
            <svg v-else-if="slot.icon === 'assistant'" width="13" height="13" viewBox="0 0 24 24" fill="currentColor" stroke="none">
              <path d="M12 3l1.6 5.4L19 10l-5.4 1.6L12 17l-1.6-5.4L5 10l5.4-1.6z" />
            </svg>
          </div>
          <div style="flex: 1; min-width: 0">
            <div class="slotrow-name">{{ slot.n }}. {{ slot.kind === 'perm' ? slot.name : `Слот ${slot.n}` }}</div>
            <div class="slotrow-meta">
              {{ EDGE_OPTIONS.find((o) => o.value === slot.edge)?.label }} ·
              {{ MONITOR_OPTIONS.find((o) => o.value === slot.monitor)?.label }} · {{ slot.width }}%
            </div>
          </div>
          <div class="slotrow-right">
            <div class="status" :style="{ color: statusFor(slot).color }">
              <span class="dot" :style="{ background: statusFor(slot).dot }"></span>{{ statusFor(slot).text }}
            </div>
            <div
              class="pill"
              :style="{
                background: slot.kind === 'perm' ? 'var(--accent-tint)' : 'var(--neutral-bg)',
                color: slot.kind === 'perm' ? 'var(--accent-fg)' : 'var(--neutral-text)',
              }"
            >
              {{ slot.kind === 'perm' ? 'Постоянный' : 'Динамический' }}
            </div>
          </div>
        </div>
      </div>

      <div class="detail" v-if="selectedSlot">
        <div class="detail-head">
          <h2>Слот {{ selectedSlot.n }}</h2>
          <button v-if="selectedSlot.kind === 'perm'" class="btn-danger-hd" @click="makeDynamic">
            Сделать динамическим…
          </button>
          <button v-else class="btn-primary-sm" @click="makePermanent">Сделать постоянным…</button>
        </div>
        <div class="detail-divider"></div>

        <template v-if="selectedSlot.kind === 'perm'">
          <div class="row">
            <label>Имя</label>
            <div class="field"><input class="in-name" type="text" v-model="selectedSlot.name" /></div>
          </div>
          <div class="row">
            <label>Файл (exe)</label>
            <div class="field">
              <input class="in-exe" type="text" v-model="selectedSlot.exe" />
              <button class="btn-icon" title="Обзор…" @click="bridge.pickExe(selectedSlot.n)">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round">
                  <path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7z" />
                </svg>
              </button>
              <button class="btn-icon" title="Окно…" @click="bridge.pickWindow(selectedSlot.n)">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round">
                  <rect x="3" y="4" width="18" height="14" rx="1.5" />
                  <line x1="3" y1="8" x2="21" y2="8" />
                </svg>
              </button>
              <div class="info-ico" tabindex="0">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                  <circle cx="12" cy="12" r="9" />
                  <line x1="12" y1="11" x2="12" y2="16" />
                  <circle cx="12" cy="8" r="1" fill="currentColor" stroke="none" />
                </svg>
                <div class="tip">
                  Класс окна (ahk_class): <code>{{ selectedSlot.cls || '—' }}</code>. Уточняет, какое
                  именно окно ловить, если под этим exe их несколько. Заполняется автоматически кнопкой
                  «Окно…» — вручную трогать обычно не нужно.
                </div>
              </div>
            </div>
          </div>
          <div class="row">
            <label>Монитор</label>
            <div class="field">
              <select class="dd" v-model="selectedSlot.monitor">
                <option v-for="o in MONITOR_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
              </select>
            </div>
          </div>
          <div class="row">
            <label>Край</label>
            <div class="field">
              <select class="dd" v-model="selectedSlot.edge">
                <option v-for="o in EDGE_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
              </select>
            </div>
          </div>
          <div class="row">
            <label>Ширина (%)</label>
            <div class="field"><input class="num-sm" type="text" v-model="selectedSlot.width" /></div>
          </div>
          <div class="check-row">
            <input type="checkbox" v-model="selectedSlot.activateOnShow" />
            <span>Активировать окно при выезде</span>
          </div>
          <div class="check-row">
            <input type="checkbox" v-model="selectedSlot.hideOnBlur" />
            <span>Убирать окно, когда фокус ушёл</span>
          </div>
          <div class="row">
            <label>Горячая клавиша</label>
            <div class="field">
              <input type="text" v-model="selectedSlot.hotkey" style="width: 126px" />
            </div>
          </div>
          <div class="hotkey-cap">после перезапуска</div>
        </template>

        <template v-else>
          <div class="detail-row"><div class="l">Имя</div><div class="v">—</div><div class="s">по умолчанию</div></div>
          <div class="detail-row"><div class="l">Файл (exe)</div><div class="v">(пусто)</div><div class="s">по умолчанию</div></div>
          <div class="detail-row">
            <div class="l">Монитор</div>
            <div class="v">{{ MONITOR_OPTIONS.find((o) => o.value === state.general.monitor)?.label }}</div>
            <div class="s">из [dynamic]</div>
          </div>
          <div class="detail-row">
            <div class="l">Край</div>
            <div class="v">{{ EDGE_OPTIONS.find((o) => o.value === state.general.edge)?.label }}</div>
            <div class="s">из [dynamic]</div>
          </div>
          <div class="detail-row">
            <div class="l">Ширина (%)</div>
            <div class="v">{{ state.general.sizePercent }}</div>
            <div class="s">из [dynamic]</div>
          </div>
          <div class="detail-row">
            <div class="l">Активировать при выезде</div>
            <div class="v">{{ state.general.activateOnShow }}</div>
            <div class="s">из [dynamic]</div>
          </div>
          <div class="detail-row" style="border-bottom: none">
            <div class="l">Горячая клавиша</div>
            <div class="v">Ctrl + Alt + {{ selectedSlot.n }}</div>
            <div class="s">по номеру</div>
          </div>

          <div class="free-note">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--accent-fg)" stroke-width="2" stroke-linecap="round" style="flex: 0 0 auto">
              <circle cx="12" cy="12" r="9" />
              <line x1="12" y1="8" x2="12" y2="13" />
              <circle cx="12" cy="16" r="1" fill="var(--accent-fg)" stroke="none" />
            </svg>
            <div>
              Слот свободен и использует общие настройки динамических слотов (вкладка General).
              Сделайте его постоянным, чтобы задать своё приложение и хоткей.
            </div>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
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
  width: 188px;
  padding-right: 32px;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%239A9CA3' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 10px center;
  background-size: 15px 15px;
}
.in-name {
  width: 208px;
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
}
.detail-row .v {
  flex: 1;
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
