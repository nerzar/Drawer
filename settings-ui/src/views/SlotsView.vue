<script setup>
import { computed, ref, watch } from 'vue'
import { settings, pickSlot, releaseSlot } from '../bridge/settings'
import { fieldTarget } from '../bridge/fieldError'
import { EDGE_OPTIONS } from '../bridge/general'
import { resetToShared } from '../bridge/slotDraft'
import {
  useSlotStatus,
  edgeLabels,
  monitorLabel,
  rowLabel,
  slotBehavior,
  slotIcon,
  slotLabel,
  statusFor,
} from '../bridge/slots'

const selectedNumber = ref(1)
const slots = computed(() => settings.canonical?.slots ?? [])
const selectedSlot = computed(() => slots.value.find((s) => s.number === selectedNumber.value))

// Что действует у выбранного слота: у постоянного — его собственные
// значения, у динамического — унаследованные с учётом его секции.
const behavior = computed(() => selectedSlot.value && slotBehavior(selectedSlot.value))

// Правится черновик, а не canonical: вернуться в canonical значения
// могут единственным путём — Применить/ОК.
const draft = computed(() => settings.slotDrafts[selectedNumber.value])
const watchError = useSlotStatus()

// Куда указывает ошибка последнего ответа. Подсвечивается контрол
// того слота, который назвал backend, — и он же выбирается в списке:
// ошибка про слот 3 на открытом слоте 1 подсветила бы чужое поле.
const target = computed(() => fieldTarget(settings.field))
const bad = (key) => {
  const t = target.value
  return Boolean(t) && t.tab === 'slots' && t.slot === selectedNumber.value && t.control === key
}

watch(
  target,
  (t) => {
    if (t && t.tab === 'slots' && slots.value.some((s) => s.number === t.slot))
      selectedNumber.value = t.slot
  },
  { immediate: true },
)

// Какие значения динамический слот держит своими, а какие берёт из
// General. Считается по применённому состоянию, а не по черновику:
// подпись описывает то, что действует, а не то, что набрано.
const OVERRIDE_NAMES = {
  monitor: 'монитор',
  edge: 'край',
  widthPercent: 'ширина',
  activateOnShow: 'активация',
  hideOnBlur: 'автоскрытие',
}

const overrideNote = computed(() => {
  const shared = settings.canonical?.general.dynamicDefaults
  const applied = behavior.value
  if (!shared || !applied) return ''
  const own = Object.keys(OVERRIDE_NAMES).filter(
    (k) => JSON.stringify(applied[k]) !== JSON.stringify(shared[k]),
  )
  return own.length
    ? `своё в [dynamicSlot${selectedNumber.value}]: ${own.map((k) => OVERRIDE_NAMES[k]).join(', ')}`
    : 'всё из [dynamic] — общих настроек динамических слотов'
})

// Форма правит черновик, поэтому род слота на экране — из черновика, а
// не из canonical: переключённая кнопка обязана менять панель сразу, а
// не после Save.
const kind = computed(() => draft.value?.kind ?? selectedSlot.value?.kind ?? 'dynamic')
const locked = computed(() => settings.status === 'saving' || settings.pickerActive)

// Смена рода — правка черновика, как и всё остальное: на диск ничего не
// уходит до «Применить»/«ОК».
function makeDynamic() {
  const d = draft.value
  const shared = settings.canonical?.general.dynamicDefaults
  if (!d || !shared || locked.value) return
  d.kind = 'dynamic'
  // Поведение возвращается к общим: секция [slotN] уходит, собственной
  // надстройки у слота не появляется — ровно то, что делает native.
  resetToShared(d, shared)
}

function makePermanent() {
  const d = draft.value
  if (!d || locked.value) return
  d.kind = 'permanent'
}

function captureHotkey(event) {
  if (event.key === 'Control' || event.key === 'Alt' || event.key === 'Shift' || event.key === 'Meta') return
  event.preventDefault()
  const key = event.key === ' ' ? 'Space' : event.key.length === 1 ? event.key.toUpperCase() : event.key
  const parts = []
  if (event.ctrlKey) parts.push('Ctrl')
  if (event.altKey) parts.push('Alt')
  if (event.shiftKey) parts.push('Shift')
  if (event.metaKey) parts.push('Win')
  parts.push(key)
  if (draft.value) draft.value.hotkey = parts.join(' + ')
}

function resetDynamic() {
  const d = draft.value
  const shared = settings.canonical?.general.dynamicDefaults
  if (!d || !shared || locked.value) return
  resetToShared(d, shared)
}
</script>

<template>
  <div class="content">
    <h1 class="page-title">Слоты Drawer</h1>
    <p class="page-sub">Настройте слоты для приложений и горячие клавиши.</p>
    <p v-if="watchError" class="page-sub" role="alert">
      Обновление состояний недоступно: {{ watchError }}
    </p>

    <div v-if="!settings.canonical" class="page-sub">
      {{ settings.message || 'Читаем настройки…' }}
    </div>

    <div v-else class="split" data-testid="slots">
      <div class="list" aria-label="Слоты">
        <button
          v-for="slot in slots"
          :key="slot.number"
          class="slotrow"
          type="button"
          :data-testid="`slot-${slot.number}`"
          :data-status="slot.status.state"
          :aria-pressed="slot.number === selectedNumber"
          :style="{ background: slot.number === selectedNumber ? 'var(--accent-tint)' : 'transparent' }"
          @click="selectedNumber = slot.number"
        >
          <div
            class="avatar"
            :class="{ 'avatar-empty': slot.kind !== 'permanent' && !slotIcon(slot) }"
          >
            <!-- Иконка самого приложения, пока окно у слота есть. Её
                 отдаёт Ящик data-URI: своей картинки у config.ini нет, а
                 придумывать её по имени файла — гадание. Без окна остаётся
                 общий знак: он говорит «слот занят», не притворяясь, что
                 узнал программу. -->
            <img v-if="slotIcon(slot)" :src="slotIcon(slot)" alt="" data-testid-icon="1" />
            <svg v-else-if="slot.kind === 'permanent'" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round">
              <rect x="3" y="4" width="18" height="14" rx="1.5" />
              <line x1="3" y1="8" x2="21" y2="8" />
            </svg>
          </div>
          <div style="flex: 1; min-width: 0">
            <div class="slotrow-name">{{ slot.number }}. {{ rowLabel(slot) }}</div>
            <div class="slotrow-meta">
              {{ edgeLabels[slotBehavior(slot).edge] }} ·
              {{ monitorLabel(slotBehavior(slot).monitor) }} · {{ slotBehavior(slot).widthPercent }}%
            </div>
          </div>
          <div class="slotrow-right">
            <div class="status" :style="{ color: statusFor(slot.status).color }">
              <span class="dot" :style="{ background: statusFor(slot.status).dot }"></span>
              {{ statusFor(slot.status).text }}
            </div>
            <div
              class="pill"
              :style="{
                background: slot.kind === 'permanent' ? 'var(--accent-tint)' : 'var(--neutral-bg)',
                color: slot.kind === 'permanent' ? 'var(--accent-fg)' : 'var(--neutral-text)',
              }"
            >
              {{ slot.kind === 'permanent' ? 'Постоянный' : 'Динамический' }}
            </div>
          </div>
        </button>
      </div>

      <div v-if="selectedSlot" class="detail" data-testid="slot-detail">
        <div class="detail-head">
          <h2>Слот {{ selectedSlot.number }}</h2>
          <!-- Смена рода — правка черновика: панель меняется сразу,
               config.ini — только по «Применить»/«ОК». -->
          <button
            v-if="kind === 'permanent'"
            class="btn-danger-hd"
            type="button"
            data-testid="make-dynamic"
            :disabled="locked"
            title="Секция [slot N] будет удалена по «Применить»"
            @click="makeDynamic()"
          >
            Сделать динамическим…
          </button>
          <button
            v-if="kind === 'dynamic' && selectedSlot.status.state !== 'empty'"
            class="btn-danger-hd"
            type="button"
            data-testid="release-slot"
            :disabled="locked"
            @click="releaseSlot(selectedNumber)"
          >
            Освободить слот
          </button>
          <button
            v-if="kind === 'dynamic'"
            class="btn-primary-sm"
            type="button"
            data-testid="reset-dynamic-settings"
            :disabled="locked"
            @click="resetDynamic()"
          >
            Сбросить к General
          </button>
          <button
            v-if="kind === 'dynamic'"
            class="btn-primary-sm"
            type="button"
            data-testid="make-permanent"
            :disabled="locked"
            @click="makePermanent()"
          >
            Сделать постоянным…
          </button>
        </div>
        <div class="detail-divider"></div>

        <!-- Живое состояние окна. В макете его не было — тогда его не
             было и в Ящике; строка та же, что у остальных фактов. -->
        <div class="detail-row">
          <div class="l">Состояние</div>
          <div class="v">{{ statusFor(selectedSlot.status).text }}</div>
        </div>
        <div class="detail-row" style="margin-bottom: 14px">
          <div class="l">Окно</div>
          <div class="v" data-testid="slot-title">{{ selectedSlot.status.windowTitle || '—' }}</div>
        </div>

        <template v-if="kind === 'permanent'">
          <fieldset v-if="draft" class="editor" :disabled="locked">
            <div class="row">
              <label for="slot-name">Имя</label>
              <div class="field">
                <input
                  id="slot-name"
                  class="in-name"
                  type="text"
                  readonly
                  data-testid="edit-name"
                  :class="{ 'field-bad': bad('name') }"
                  :aria-invalid="bad('name')"
                  v-model="draft.name"
                />
              </div>
            </div>
            <div class="row">
              <label for="slot-exe">Файл (exe)</label>
              <div class="field">
                <input
                  id="slot-exe"
                  class="in-exe"
                  type="text"
                  data-testid="edit-executable"
                  :class="{ 'field-bad': bad('executable') }"
                  :aria-invalid="bad('executable')"
                  v-model="draft.executable"
                />
                <button class="btn-icon" type="button" title="Обзор…" data-testid="pick-exe" @click="pickSlot(selectedNumber, 'exe')">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round">
                    <path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7z" />
                  </svg>
                </button>
                <button class="btn-icon" type="button" title="Окно…" data-testid="pick-window" @click="pickSlot(selectedNumber, 'window')">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round">
                    <rect x="3" y="4" width="18" height="14" rx="1.5" />
                    <line x1="3" y1="8" x2="21" y2="8" />
                  </svg>
                </button>
                <div class="info-ico" tabindex="0">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" style="transform: translate(3%, 2%)">
                    <circle cx="12" cy="12" r="9" />
                    <line x1="12" y1="11" x2="12" y2="16" />
                    <circle cx="12" cy="8" r="1" fill="currentColor" stroke="none" />
                  </svg>
                  <div class="tip">
                    Класс окна (ahk_class): <code data-testid="slot-class">{{ draft.windowClass || '—' }}</code>.
                    Уточняет, какое именно окно ловить, если под этим exe их несколько.
                    Заполняется кнопкой «Окно…».
                  </div>
                </div>
              </div>
            </div>
            <div class="row">
              <label for="slot-monitor">Монитор</label>
              <div class="field">
                <select
                  id="slot-monitor"
                  class="dd"
                  data-testid="edit-monitorKind"
                  :class="{ narrow: draft.monitorKind === 'number', 'field-bad': bad('monitor') }"
                  v-model="draft.monitorKind"
                >
                  <option value="cursor">Под курсором</option>
                  <option value="number">Номер монитора</option>
                  <!-- Значение из файла, которого не бывает у контролов.
                       Пункт есть, пока его не заменили: подставить cursor
                       значило бы поменять настройку молча. -->
                  <option v-if="draft.monitorKind === 'invalid'" value="invalid">
                    в файле: {{ draft.monitorRaw }}
                  </option>
                </select>
                <input
                  v-if="draft.monitorKind === 'number'"
                  class="num-sm"
                  type="text"
                  data-testid="edit-monitorNumber"
                  :class="{ 'field-bad': bad('monitor.number') }"
                  v-model="draft.monitorNumber"
                />
              </div>
            </div>
            <div class="row">
              <label for="slot-edge">Край</label>
              <div class="field">
                <select id="slot-edge" class="dd" data-testid="edit-edge" v-model="draft.edge">
                  <option v-for="o in EDGE_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
                </select>
              </div>
            </div>
            <div class="row">
              <label for="slot-width">Ширина (%)</label>
              <div class="field">
                <input
                  id="slot-width"
                  class="num-sm"
                  type="text"
                  data-testid="edit-widthPercent"
                  :class="{ 'field-bad': bad('widthPercent') }"
                  :aria-invalid="bad('widthPercent')"
                  v-model="draft.widthPercent"
                />
              </div>
            </div>
            <label class="check-row">
              <input type="checkbox" data-testid="edit-activateOnShow" v-model="draft.activateOnShow" />
              <span>Активировать окно при выезде</span>
            </label>
            <label class="check-row">
              <input type="checkbox" data-testid="edit-hideOnBlur" v-model="draft.hideOnBlur" />
              <span>Убирать окно, когда фокус ушёл</span>
            </label>
            <div class="row">
              <label for="slot-hotkey">Горячая клавиша</label>
              <div class="field">
                <input
                  id="slot-hotkey"
                  type="text"
                  style="width: 160px"
                  placeholder="Ctrl + Alt + F2"
                  data-testid="edit-hotkey"
                  :class="{ 'field-bad': bad('hotkey') }"
                  :value="draft.hotkey"
                  @keydown="captureHotkey"
                />
              </div>
            </div>
            <div class="hotkey-cap">show/hide, применяется сразу</div>
          </fieldset>
        </template>

        <template v-else>
          <!-- Имени, файла и своего хоткея у динамического слота нет —
               это факты, а не поля. Поведение он настраивает: секция
               [dynamicSlotN] надстраивается над общей [dynamic]. -->
          <div class="detail-row">
            <div class="l">Имя</div>
            <div class="v">{{ slotLabel(selectedSlot) }}</div>
            <div class="s">по умолчанию</div>
          </div>
          <div class="detail-row" style="margin-bottom: 12px">
            <div class="l">Файл (exe)</div>
            <div class="v">(пусто)</div>
            <div class="s">по умолчанию</div>
          </div>

          <fieldset v-if="draft" class="editor" :disabled="locked">
            <div class="row">
              <label for="dyn-monitor">Монитор</label>
              <div class="field">
                <select
                  id="dyn-monitor"
                  class="dd"
                  data-testid="edit-monitorKind"
                  :class="{ narrow: draft.monitorKind === 'number', 'field-bad': bad('monitor') }"
                  v-model="draft.monitorKind"
                >
                  <option value="cursor">Под курсором</option>
                  <option value="number">Номер монитора</option>
                  <option v-if="draft.monitorKind === 'invalid'" value="invalid">
                    в файле: {{ draft.monitorRaw }}
                  </option>
                </select>
                <input
                  v-if="draft.monitorKind === 'number'"
                  class="num-sm"
                  type="text"
                  data-testid="edit-monitorNumber"
                  :class="{ 'field-bad': bad('monitor.number') }"
                  v-model="draft.monitorNumber"
                />
              </div>
            </div>
            <div class="row">
              <label for="dyn-edge">Край</label>
              <div class="field">
                <select id="dyn-edge" class="dd" data-testid="edit-edge" v-model="draft.edge">
                  <option v-for="o in EDGE_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
                </select>
              </div>
            </div>
            <div class="row">
              <label for="dyn-width">Ширина (%)</label>
              <div class="field">
                <input
                  id="dyn-width"
                  class="num-sm"
                  type="text"
                  data-testid="edit-widthPercent"
                  :class="{ 'field-bad': bad('widthPercent') }"
                  :aria-invalid="bad('widthPercent')"
                  v-model="draft.widthPercent"
                />
              </div>
            </div>
            <label class="check-row">
              <input type="checkbox" data-testid="edit-activateOnShow" v-model="draft.activateOnShow" />
              <span>Активировать окно при выезде</span>
            </label>
            <label class="check-row">
              <input type="checkbox" data-testid="edit-hideOnBlur" v-model="draft.hideOnBlur" />
              <span>Убирать окно, когда фокус ушёл</span>
            </label>
            <div class="row">
              <label for="dyn-hotkey">Горячая клавиша</label>
              <div class="field">
                <input id="dyn-hotkey" type="text" style="width: 160px" placeholder="Ctrl + Alt + F2"
                  data-testid="edit-hotkey" :class="{ 'field-bad': bad('hotkey') }" readonly :value="draft.hotkey" @keydown="captureHotkey" />
              </div>
            </div>
            <div class="hotkey-cap" data-testid="dyn-source">{{ overrideNote }}</div>
          </fieldset>


          <div class="free-note">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--accent-fg)" stroke-width="2" stroke-linecap="round" style="flex: 0 0 auto">
              <circle cx="12" cy="12" r="9" />
              <line x1="12" y1="8" x2="12" y2="13" />
              <circle cx="12" cy="16" r="1" fill="var(--accent-fg)" stroke="none" />
            </svg>
            <div>
              Значения, совпадающие с общими, слот берёт из вкладки General и следует
              за ними. Сделайте его постоянным, чтобы задать своё приложение и хоткей.
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
  /* Окно Ящика — 980 px, и список слотов занимает из них 358. Без
     этого правая колонка требует свою минимальную ширину целиком и
     выталкивает содержимое за край окна вместо того, чтобы ужать
     поля. */
  min-width: 0;
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
.avatar img {
  width: 16px;
  height: 16px;
  display: block;
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
.editor {
  border: 0;
  padding: 0;
  margin: 0;
  min-width: 0;
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
  justify-content: flex-end;
  gap: 6px;
  flex: 1;
  min-width: 0;
}
/* Ширины полей — предельные, а не жёсткие: в узком окне поле ужимается,
   а кнопки и знак вопроса рядом остаются целыми. */
input[type='text'],
select.dd {
  font: inherit;
  font-size: 12.5px;
  height: 28px;
  min-width: 0;
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
select.dd.narrow {
  width: 128px;
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
  flex: 0 0 auto;
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
/* Подсказка прижата к правому краю, а не отцентрована по значку:
   карточка обрезает всё, что вылезло вбок (overflow), а в подсказке
   теперь лежит значение — класс окна, и прочитать его нужно целиком. */
.info-ico .tip {
  position: absolute;
  right: 0;
  top: 26px;
  transform: translateY(-4px);
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
  transform: translateY(0);
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
  /* 160 из макета — ровно ширина самой длинной подписи, и значение
     впритык к ней читается как одно слово. Двенадцать пикселей —
     промежуток, а не новая колонка. */
  width: 172px;
  padding-right: 12px;
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
.field-bad {
  border-color: #a04a45;
}
button[disabled],
fieldset[disabled] {
  opacity: 0.5;
}
.btn-danger-hd[disabled]:hover {
  background: transparent;
}
</style>
