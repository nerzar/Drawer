<script setup>
import { bridge } from '../mock/bridge'

defineProps({
  status: { type: String, default: '' },
})
</script>

<template>
  <div class="footer">
    <div class="footer-status">{{ status }}</div>
    <button class="btn-outline" @click="bridge.cancel()">Отмена</button>
    <button class="btn-outline" @click="bridge.apply()">Применить</button>
    <button class="btn-primary" @click="bridge.ok()">ОК</button>
  </div>
</template>
