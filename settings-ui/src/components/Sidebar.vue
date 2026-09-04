<script setup>
defineProps({
  active: { type: String, required: true },
})
defineEmits(['update:active'])

const tabs = [
  { key: 'general', label: 'General' },
  { key: 'slots', label: 'Slots' },
  { key: 'about', label: 'About' },
]
</script>

<template>
  <div class="sidebar">
    <button
      v-for="tab in tabs"
      :key="tab.key"
      class="navitem"
      :class="{ active: active === tab.key }"
      @click="$emit('update:active', tab.key)"
    >
      <svg
        v-if="tab.key === 'general'"
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linecap="round"
      >
        <line x1="4" y1="6" x2="20" y2="6" />
        <circle cx="9" cy="6" r="2" fill="var(--bg-sidebar)" stroke-width="1.4" />
        <line x1="4" y1="12" x2="20" y2="12" />
        <circle cx="15" cy="12" r="2" fill="var(--bg-sidebar)" stroke-width="1.4" />
        <line x1="4" y1="18" x2="20" y2="18" />
        <circle cx="7" cy="18" r="2" fill="var(--bg-sidebar)" stroke-width="1.4" />
      </svg>
      <svg
        v-else-if="tab.key === 'slots'"
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linejoin="round"
      >
        <rect x="3" y="3" width="7" height="7" rx="1.5" />
        <rect x="14" y="3" width="7" height="7" rx="1.5" />
        <rect x="3" y="14" width="7" height="7" rx="1.5" />
        <rect x="14" y="14" width="7" height="7" rx="1.5" />
      </svg>
      <svg
        v-else
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linecap="round"
      >
        <circle cx="12" cy="12" r="9" />
        <line x1="12" y1="11" x2="12" y2="16" />
        <circle cx="12" cy="8" r="1" fill="currentColor" stroke="none" />
      </svg>
      <span>{{ tab.label }}</span>
    </button>
  </div>
</template>
