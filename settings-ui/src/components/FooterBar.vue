<script setup>
import { computed } from 'vue'
import {
  settings,
  applySettings,
  cancelSettings,
  keepEditing,
  okSettings,
  restartHint,
  diagnosticsHint,
} from '../bridge/settings'

const props = defineProps({
  status: { type: String, default: '' },
  bad: { type: Boolean, default: false },
})

// Пока идёт запрос, повторные Apply/OK не нужны: ответ связан с запросом
// по id, но вторая запись на диск во время первой — уже не гонка UI.
const busy = computed(() => settings.status === 'loading' || settings.status === 'saving')
const ready = computed(() => settings.draft !== null)
const restart = computed(() => restartHint())
const diagnostics = computed(() => diagnosticsHint())
</script>

<template>
  <!-- Вопрос о несохранённом задаёт страница, а не MsgBox из AHK: модальное
       окно на стороне моста остановило бы очередь сообщений WebView на всё
       время раздумий. Что считать несохранённым, решает порт — он один
       знает применённое состояние. -->
  <div v-if="settings.confirmDiscard" class="footer confirm" data-testid="confirm">
    <div class="footer-status">Изменения не сохранены. Закрыть и отменить их?</div>
    <button class="btn-outline" data-testid="keep" @click="keepEditing()">Продолжить правку</button>
    <button class="btn-primary" data-testid="discard" @click="cancelSettings(true)">
      Отменить изменения
    </button>
  </div>

  <div v-else class="footer">
    <div class="footer-status" :class="{ bad: props.bad }" data-testid="status">
      {{ props.status }}
      <span v-if="restart" class="restart" data-testid="restart">{{ restart }}</span>
      <span v-if="diagnostics" class="warning" data-testid="diagnostics">{{ diagnostics }}</span>
    </div>
    <button class="btn-outline" data-testid="cancel" :disabled="busy" @click="cancelSettings()">Отмена</button>
    <button class="btn-outline" data-testid="apply" :disabled="busy || !ready || settings.pickerActive" @click="applySettings()">
      Применить
    </button>
    <button class="btn-primary" data-testid="ok" :disabled="busy || !ready || settings.pickerActive" @click="okSettings()">ОК</button>
  </div>
</template>

<style scoped>
.footer-status.bad {
  color: #e2857f;
}
.restart {
  color: var(--text-2);
}
.warning {
  color: #e5a95a;
  margin-left: 8px;
}
button[disabled] {
  opacity: 0.5;
}
</style>
