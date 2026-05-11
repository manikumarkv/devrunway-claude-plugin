---
name: react-standards
description: React best practices, performance rules, and anti-patterns. Load when writing, reviewing, or discussing any React/TypeScript frontend code, components, hooks, or state management.
user-invocable: false
---

Full rules in [react.md](react.md). Always-on summary:

**Stack (no alternatives):**
- React 18 + TypeScript strict + Vite + Tailwind CSS
- Server state: React Query v5 — never `fetch` in `useEffect`
- Routing: React Router v6
- Forms: React Hook Form + Zod
- Testing: Vitest + React Testing Library + MSW + Playwright

**Components:**
- Functional only · explicit `interface` props · max ~150 lines
- Named exports · barrel `index.ts` per feature · co-located `.test.tsx`

**Never:**
- `any` type
- `console.log` in production code
- `useEffect` for data fetching
- Components defined inside components
- Default exports inside feature folders
- Inline `style={{}}` for static values
- Business logic in component body (belongs in a hook)
- Server state stored in Zustand/Redux

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
