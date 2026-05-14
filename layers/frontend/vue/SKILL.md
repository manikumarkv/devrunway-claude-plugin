---
name: vue
description: Vue 3 standards — Composition API, script setup, composables, reactivity, and TypeScript patterns. Load when working with Vue 3.
user-invocable: false
stack: frontend/vue
paths:
  - "**/*.vue"
  - "**/composables/**"
  - "src/views/**"
  - "src/components/**"
---

Full standards in [vue.md](vue.md). Always-on summary:

**Component format:**
- Use `<script setup lang="ts">` — it's the default for Vue 3 Composition API
- Keep `<script setup>` focused on component logic only — extract reusable logic to composables
- Order in SFC: `<script setup>` → `<template>` → `<style scoped>`

**Reactivity:**
- Use `ref()` for primitives and single values; `reactive()` for objects (with caution — destructuring breaks reactivity)
- Prefer `ref()` over `reactive()` when in doubt — `.value` access is explicit and consistent
- Derived state: `computed(() => ...)` — never store computed values in `ref()`
- Side effects: `watchEffect()` for auto-tracked effects; `watch(source, handler)` when you need the old value or to watch specific sources

**Composables:**
- Extract reusable stateful logic into `use*` composables in `src/composables/`
- Return reactive refs/computed from composables — not plain values
- Follow the `useXxx(options?)` naming convention
- Composables can call other composables

**Props and emits:**
- Define props with `defineProps<{ ... }>()` — TypeScript generics, no runtime options object
- Define emits with `defineEmits<{ (e: 'update', val: string): void }>()` — typed event signatures
- Use `v-model:propName` for two-way binding; implement with `modelValue` prop + `update:modelValue` emit

**Template:**
- Use `v-bind` shorthand (`:prop`) and `v-on` shorthand (`@event`) consistently
- `v-if` and `v-for` on the same element: `v-if` has higher priority — use a wrapping `<template>` instead
- Always use `:key` on `v-for` — stable, unique key (not array index for mutable lists)

**Never:**
- Mutate props directly — emit an event or use `v-model`
- Use `this` — Composition API doesn't use it
- Mix Options API and Composition API in the same component
- Use `reactive()` and then destructure — you lose reactivity

**Related skills:** `state/pinia` (Vue-native state management), `validation/valibot` or `validation/zod`
