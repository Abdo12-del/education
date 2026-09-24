<template>
  <div class="flex flex-col gap-4 px-5 py-4">
    <div class="flex items-center justify-between">
      <h2 class="text-2xl font-semibold">Notices</h2>
      <span class="text-sm text-gray-500">{{ notices.data?.length || 0 }} notices</span>
    </div>

    <div
      v-if="notices.loading"
      class="rounded-lg border border-gray-200 bg-white p-6 text-center text-gray-400"
    >
      Loading notices…
    </div>

    <div v-else-if="notices.data?.length">
      <div
        v-for="notice in notices.data"
        :key="notice.name"
        class="mb-3 rounded-lg border border-gray-200 bg-white p-4 shadow-sm"
      >
        <div class="flex flex-wrap items-center gap-2">
          <span
            class="rounded-full px-2 py-0.5 text-xs font-medium"
            :class="priorityClass(notice.priority)"
          >
            {{ notice.priority }}
          </span>
          <span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700">
            {{ notice.notice_type }}
          </span>
          <span class="ml-auto text-xs text-gray-400">{{ notice.publish_date }}</span>
        </div>
        <h3 class="mt-2 text-lg font-semibold text-gray-800">{{ notice.title }}</h3>
        <p class="mt-1 whitespace-pre-wrap text-sm text-gray-600">{{ notice.content }}</p>
        <a
          v-if="notice.attachment"
          :href="notice.attachment"
          class="mt-2 inline-block text-sm font-medium text-blue-600 hover:underline"
        >
          📎 Attachment
        </a>
      </div>
    </div>

    <div
      v-else
      class="rounded-lg border border-dashed border-gray-300 bg-white p-8 text-center text-gray-400"
    >
      No published notices yet — check back later.
    </div>
  </div>
</template>

<script setup>
import { createResource } from 'frappe-ui'

const notices = createResource({
  url: 'education.education.api.get_published_notices',
  auto: true,
})

function priorityClass(priority) {
  if (priority === 'Urgent') return 'bg-red-100 text-red-700'
  if (priority === 'High') return 'bg-amber-100 text-amber-700'
  return 'bg-blue-100 text-blue-700'
}
</script>
