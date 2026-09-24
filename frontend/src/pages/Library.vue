<template>
  <div class="flex flex-col gap-4 px-5 py-4">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h2 class="text-2xl font-semibold">My Library</h2>
      <div v-if="library.data?.member" class="text-sm text-gray-500">
        Member
        <span class="font-medium text-gray-700">{{ library.data.member.name }}</span>
        · allowed books:
        <span class="font-medium">{{ library.data.member.max_books_allowed }}</span>
      </div>
    </div>

    <div
      v-if="library.loading"
      class="rounded-lg border border-gray-200 bg-white p-6 text-center text-gray-400"
    >
      Loading your library records…
    </div>

    <div
      v-else-if="library.data && !library.data.member"
      class="rounded-lg border border-dashed border-gray-300 bg-white p-8 text-center text-gray-400"
    >
      You don't have a library membership yet — ask the school librarian to register you.
    </div>

    <template v-else-if="library.data?.transactions?.length">
      <div class="overflow-hidden rounded-lg border border-gray-200 bg-white">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 text-left text-xs uppercase tracking-wide text-gray-500">
            <tr>
              <th class="px-4 py-3">Book</th>
              <th class="px-4 py-3">Type</th>
              <th class="px-4 py-3">Issued</th>
              <th class="px-4 py-3">Due</th>
              <th class="px-4 py-3">Returned</th>
              <th class="px-4 py-3">Fine</th>
              <th class="px-4 py-3">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr v-for="tx in library.data.transactions" :key="tx.name">
              <td class="px-4 py-3 font-medium text-gray-800">{{ tx.book_title }}</td>
              <td class="px-4 py-3 text-gray-500">{{ tx.transaction_type }}</td>
              <td class="px-4 py-3 text-gray-500">{{ tx.issue_date }}</td>
              <td class="px-4 py-3" :class="tx.overdue ? 'font-semibold text-red-600' : 'text-gray-500'">
                {{ tx.due_date }}
                <span v-if="tx.overdue" class="ml-1 rounded bg-red-100 px-1.5 py-0.5 text-xs">overdue</span>
              </td>
              <td class="px-4 py-3 text-gray-500">{{ tx.return_date || '—' }}</td>
              <td class="px-4 py-3 text-gray-500">{{ tx.fine_amount || 0 }}</td>
              <td class="px-4 py-3">
                <span
                  class="rounded-full px-2 py-0.5 text-xs font-medium"
                  :class="
                    tx.status === 'Returned'
                      ? 'bg-green-100 text-green-700'
                      : 'bg-amber-100 text-amber-700'
                  "
                >
                  {{ tx.status }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        v-if="overdueCount"
        class="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
      >
        ⚠ You have {{ overdueCount }} overdue book(s). Please return them as soon as possible.
      </div>
    </template>

    <div
      v-else
      class="rounded-lg border border-dashed border-gray-300 bg-white p-8 text-center text-gray-400"
    >
      No books issued yet — enjoy browsing the catalogue!
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { createResource } from 'frappe-ui'

const library = createResource({
  url: 'education.education.api.get_my_library',
  auto: true,
})

const overdueCount = computed(
  () => library.data?.transactions?.filter((tx) => tx.overdue).length || 0,
)
</script>
