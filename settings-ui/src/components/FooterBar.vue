<script setup>
import { computed } from 'vue'
import { settings, applySettings, cancelSettings, okSettings } from '../bridge/settings'

const props = defineProps({
  status: { type: String, default: '' },
  bad: { type: Boolean, default: false },
})

// Пока идёт запрос, повторные Apply/OK не нужны: ответ связан с запросом
// по id, но вторая запись на диск во время первой — уже не гонка UI.
const busy = computed(() => settings.status === 'loading' || settings.status === 'saving')
const ready = computed(() => settings.canonical !== null)
</script>

<template>
  <div class="footer">
    <div class="footer-status" :class="{ bad: props.bad }" data-testid="status">{{ props.status }}</div>
    <button class="btn-outline" data-testid="cancel" :disabled="busy" @click="cancelSettings()">Отмена</button>
    <button class="btn-outline" data-testid="apply" :disabled="busy || !ready" @click="applySettings()">
      Применить
    </button>
    <button class="btn-primary" data-testid="ok" :disabled="busy || !ready" @click="okSettings()">ОК</button>
  </div>
</template>

<style scoped>
.footer-status.bad {
  color: #e2857f;
}
button[disabled] {
  opacity: 0.5;
}
</style>
