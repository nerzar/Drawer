<script setup>
import { ref, computed } from 'vue'
import { state } from './mock/state'
import TitleBar from './components/TitleBar.vue'
import Sidebar from './components/Sidebar.vue'
import FooterBar from './components/FooterBar.vue'
import GeneralView from './views/GeneralView.vue'
import SlotsView from './views/SlotsView.vue'
import AboutView from './views/AboutView.vue'

const activeTab = ref('general')

const currentView = computed(() => {
  if (activeTab.value === 'slots') return SlotsView
  if (activeTab.value === 'about') return AboutView
  return GeneralView
})
</script>

<template>
  <div class="app" :style="{ '--accent': state.accent }">
    <TitleBar />
    <div class="body-row">
      <Sidebar v-model:active="activeTab" />
      <component :is="currentView" />
    </div>
    <FooterBar />
  </div>
</template>
