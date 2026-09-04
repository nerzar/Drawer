<script setup>
defineProps({
  size: { type: Number, default: 18 },
})
</script>

<template>
  <svg :width="size" :height="size" viewBox="0 0 24 24">
    <defs>
      <linearGradient :id="`logo-grad-${size}`" x1="0" y1="0" x2="24" y2="24">
        <stop offset="0" stop-color="#1B3FA8" />
        <stop offset="1" stop-color="#3B93F2" />
      </linearGradient>
    </defs>
    <rect x="1" y="1" width="22" height="22" rx="6" :fill="`url(#logo-grad-${size})`" />
    <path d="M9 5.5 6 8v8l3 2.5z" fill="#fff" />
    <path
      d="M10 7l6 5-6 5"
      stroke="#fff"
      stroke-width="2"
      fill="none"
      stroke-linecap="round"
      stroke-linejoin="round"
    />
  </svg>
</template>
