<script setup>
import { computed, onMounted, watch } from 'vue'
import { settings, loadSettings } from './bridge/settings'
import { fieldTarget } from './bridge/fieldError'
import { setLocale } from './i18n'
import Sidebar from './components/Sidebar.vue'
import FooterBar from './components/FooterBar.vue'
import GeneralView from './views/GeneralView.vue'
import SlotsView from './views/SlotsView.vue'
import AboutView from './views/AboutView.vue'
import { ref } from 'vue'

const activeTab = ref('general')
const selectedSlotNumber = ref(1)

const currentView = computed(() => {
  if (activeTab.value === 'slots') return SlotsView
  if (activeTab.value === 'about') return AboutView
  return GeneralView
})

// Первый запрос к Ящику. До ответа форма показывает «Читаем настройки…»
// и ничего не выдумывает: canonical принадлежит AHK.
onMounted(loadSettings)

// Ответ с адресом поля переводит на ту вкладку, где это поле живёт.
// Иначе сообщение внизу говорит про слот, которого на экране нет, и
// подсвечивать оказывается нечего. Сохраняем выбранный слот в родителе,
// чтобы переход между вкладками не сбрасывал выбор.
watch(
  () => settings.field,
  (field) => {
    const target = fieldTarget(field)
    if (target) {
      activeTab.value = target.tab
      if (target.tab === 'slots' && target.slot) {
        selectedSlotNumber.value = target.slot
      }
    }
  },
)

// Акцент берётся из черновика, а не из применённого: выбранный цвет
// виден сразу всему окну — тот же предпросмотр, что и у native, только
// не в одном квадратике. До загрузки — цвет по умолчанию из config.ini.
const accent = computed(() => '#' + (settings.draft?.accent ?? '2A2E35'))

// Язык — тем же путём, что и акцент: черновик меняет его сразу, ещё до
// «Применить»/«ОК», а не после перезапуска. До загрузки и пока черновик
// не заведён — canonical, иначе умолчание совпадёт с AHK ("ru").
watch(
  () => settings.draft?.locale ?? settings.canonical?.general.locale ?? 'ru',
  (next) => setLocale(next),
  { immediate: true },
)
</script>

<template>
  <div class="app" :style="{ '--accent': accent }">
    <div class="body-row">
      <Sidebar v-model:active="activeTab" />
      <component
        :is="currentView"
        :selected-slot="selectedSlotNumber"
        @update:selected-slot="selectedSlotNumber = $event"
      />
    </div>
    <FooterBar :status="settings.message" :bad="settings.bad" />
  </div>
</template>
