<script setup>
import logoUrl from '../assets/app-logo.png'

defineProps({
  size: { type: Number, default: 18 },
})
</script>

<template>
  <img
    :src="logoUrl"
    :width="size"
    :height="size"
    alt="Drawer"
    class="app-logo"
  />
</template>

<style scoped>
.app-logo {
  display: block;
  border-radius: 22%;
}
</style>
