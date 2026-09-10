<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import {
  settings,
  applySettings,
  cancelSettings,
  keepEditing,
  okSettings,
  restartHint,
  diagnosticsHint,
} from '../bridge/settings'
import { t } from '../i18n'

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

const keepButtonRef = ref(null)
watch(
  () => settings.confirmDiscard,
  async (active) => {
    if (active) {
      await nextTick()
      keepButtonRef.value?.focus()
    }
  },
)
</script>

<template>
  <!-- Вопрос о несохранённом задаёт страница, а не MsgBox из AHK: модальное
       окно на стороне моста остановило бы очередь сообщений WebView на всё
       время раздумий. Что считать несохранённым, решает порт — он один
       знает применённое состояние. -->
  <div
    v-if="settings.confirmDiscard"
    class="footer confirm"
    data-testid="confirm"
    role="alert"
    aria-live="assertive"
  >
    <div class="footer-status">{{ t('footer.confirmMessage') }}</div>
    <button ref="keepButtonRef" class="btn-outline" data-testid="keep" @click="keepEditing()">
      {{ t('footer.keepEditing') }}
    </button>
    <button class="btn-primary" data-testid="discard" @click="cancelSettings(true)">
      {{ t('footer.discard') }}
    </button>
  </div>

  <div v-else class="footer">
    <div
      class="footer-status"
      :class="{ bad: props.bad }"
      data-testid="status"
      role="status"
      aria-live="polite"
      aria-atomic="true"
    >
      {{ props.status }}
      <span v-if="restart" class="restart" data-testid="restart">{{ restart }}</span>
      <span v-if="diagnostics" class="warning" data-testid="diagnostics">{{ diagnostics }}</span>
    </div>
    <button class="btn-outline" data-testid="cancel" :disabled="busy" @click="cancelSettings()">{{ t('footer.cancel') }}</button>
    <button class="btn-outline" data-testid="apply" :disabled="busy || !ready || settings.pickerActive" @click="applySettings()">
      {{ t('footer.apply') }}
    </button>
    <button class="btn-primary" data-testid="ok" :disabled="busy || !ready || settings.pickerActive" @click="okSettings()">{{ t('footer.ok') }}</button>
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
