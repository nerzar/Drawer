<script setup>
import AppLogo from './AppLogo.vue'
import { bridge } from '../mock/bridge'
</script>

<template>
  <div class="titlebar">
    <AppLogo :size="18" />
    <div class="titlebar-title">Drawer — Settings</div>
    <div style="flex: 1"></div>
    <button class="winbtn" aria-label="Свернуть" @click="bridge.minimize()">
      <svg width="10" height="10" viewBox="0 0 10 10">
        <line x1="0" y1="5" x2="10" y2="5" stroke="currentColor" stroke-width="1.2" />
      </svg>
    </button>
    <button class="winbtn close" aria-label="Закрыть" @click="bridge.close()">
      <svg width="10" height="10" viewBox="0 0 10 10">
        <line x1="0" y1="0" x2="10" y2="10" stroke="currentColor" stroke-width="1.2" />
        <line x1="10" y1="0" x2="0" y2="10" stroke="currentColor" stroke-width="1.2" />
      </svg>
    </button>
  </div>
</template>
