<script setup>
import { computed, onMounted } from 'vue'
import { settings, loadSettings } from './bridge/settings'
import TitleBar from './components/TitleBar.vue'
import Sidebar from './components/Sidebar.vue'
import FooterBar from './components/FooterBar.vue'
import GeneralView from './views/GeneralView.vue'
import SlotsView from './views/SlotsView.vue'
import AboutView from './views/AboutView.vue'
import { ref } from 'vue'

const activeTab = ref('general')

const currentView = computed(() => {
  if (activeTab.value === 'slots') return SlotsView
  if (activeTab.value === 'about') return AboutView
  return GeneralView
})

// Первый запрос к Ящику. До ответа форма показывает «Читаем настройки…»
// и ничего не выдумывает: canonical принадлежит AHK.
onMounted(loadSettings)

// Акцент берётся из черновика, а не из применённого: выбранный цвет
// виден сразу всему окну — тот же предпросмотр, что и у native, только
// не в одном квадратике. До загрузки — цвет по умолчанию из config.ini.
const accent = computed(() => '#' + (settings.draft?.accent ?? '2A2E35'))
</script>

<template>
  <div class="app" :style="{ '--accent': accent }">
    <TitleBar />
    <div class="body-row">
      <Sidebar v-model:active="activeTab" />
      <component :is="currentView" />
    </div>
    <FooterBar :status="settings.message" :bad="settings.bad" />
  </div>
</template>
