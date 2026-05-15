---
name: react-standards
description: React best practices, performance rules, and anti-patterns. Load when writing, reviewing, or discussing any React/TypeScript frontend code, components, hooks, or state management.
user-invocable: false
stack: frontend/reactpaths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "src/**/*.ts"
---

Full rules in [react.md](react.md). Always-on summary:

**Stack (no alternatives):**
- React 18 + TypeScript strict + Vite + Tailwind CSS
- **UI components: shadcn/ui** — always check `src/components/ui/` before building from scratch
- Server state: React Query v5 — use `useQuery(` for reads, `useMutation` for writes — never `fetch` in `useEffect`
- Routing: React Router v6
- Forms: React Hook Form — `const { register } = useForm(` with `zodResolver(schema)` for schema validation
- i18n: react-i18next — every user-visible string goes through `t()`
- Testing: Vitest + React Testing Library + MSW + Playwright

**Single-file rules (enforced, no exceptions):**
- `src/lib/constants.ts` — every magic value (numbers, limits, timeouts, locale list)
- `src/lib/api-routes.ts` — every API endpoint path, including parameterised ones
- `src/lib/i18n.ts` — i18next init; `src/locales/<lang>/<namespace>.json` for strings
- Never inline a URL string, page size, debounce delay, or user-visible label in a component

**shadcn/ui rules:**
- Install: `npx shadcn@latest add <component>` — copies source into `src/components/ui/`
- Never hand-edit `src/components/ui/` files — re-run the CLI to update
- Always import from `@/components/ui/<name>`, never from `radix-ui` directly
- Use `cn()` from `src/lib/utils.ts` for all conditional class merging — never string template literals
- Custom composite components live in `src/shared/components/` and wrap shadcn primitives
- Forms always use shadcn `<Form>`, `<FormField>`, `<FormItem>`, `<FormLabel>`, `<FormControl>`, `<FormMessage>` wrappers around React Hook Form

**Components:**
- Functional only · explicit `interface` props · max ~150 lines
- Named exports · barrel `index.ts` per feature · co-located `.test.tsx`

**URL accessibility — every view must be deep-linkable:**
- Every feature has a dedicated route — create → `/resource/new`, edit → `/resource/:id/edit`, detail → `/resource/:id`
- All list state (filters, search, sort, cursor) lives in URL search params via `useSearchParams()` — never in `useState`
- Tab selection → `?tab=` in URL. Browser back button must restore previous state
- After create/edit mutations, `navigate()` to the detail page — never stay on the same page and show a modal

**UI patterns — modals and notifications:**
- **Modals (`AlertDialog`) only for destructive confirmations** — "Delete?" / "Archive all?" — never for create/edit forms
- **All feedback via toast (Sonner)** — `toast.success()` · `toast.error()` · `toast.warning()` · `toast.promise()`
- Inline `<FormMessage />` for field-level validation errors — not a toast
- `<Toaster position="bottom-right" richColors />` mounted once in `App.tsx`

**Never:**
- `any` type
- Raw stdout logging (`console.*`) in production code — use Pino `logger.*` methods or Sentry
- `useEffect` for data fetching
- Components defined inside components
- Default exports inside feature folders
- Inline `style={{}}` for static values
- Business logic in component body (belongs in a hook)
- Server state stored in Zustand/Redux
- Build a button, input, dialog, select, table, or badge from scratch — use shadcn
- Open a create/edit form in a modal — give it its own page/route
- Show success/error/warning in a modal alert — use `toast` instead

**Re-render rules (see react.md for full examples):**
- Hoist static JSX and non-primitive defaults outside components
- Functional `setState` for stable callback refs
- Primitive useEffect dependencies, never objects
- `useMemo` only for genuinely expensive computations
- `startTransition` for non-urgent updates
- `useRef` for values that change without needing re-renders

**Performance rules (see react.md for full examples):**
- `Promise.all()` for independent async operations — never sequential awaits
- `React.lazy` + `Suspense` for heavy components
- Direct imports, never barrel imports
- Map/Set for O(1) lookups instead of array.find/includes
- Hoist RegExp to module scope
- `{ passive: true }` on touch/wheel listeners


**Related skills — apply together:**
- `typescript-patterns` — type all props, events, and hook return values
- `composition-patterns` — compound components, context shape, children over render props
- `testing-standards` — every component needs loading/success/empty/error test states
- `accessibility` — semantic elements, focus management, aria attributes
- `error-handling` — error boundaries around every async feature, ApiError in mutations