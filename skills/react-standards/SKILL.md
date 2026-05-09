---
name: react-standards
description: React and frontend coding standards, patterns, approved libraries, and anti-patterns. Load when writing, reviewing, or discussing any React/TypeScript frontend code, components, hooks, or state management.
user-invocable: false
---

For the full reference see [react.md](react.md). Summary of rules that must always apply:

**Libraries (use these, no alternatives):**
- Vite + React 18 + TypeScript (strict)
- Styling: Tailwind CSS (utility-first) + CSS Modules when needed
- Server state: `@tanstack/react-query` v5
- Client state: Zustand (simple) or Redux Toolkit (complex shared state)
- Routing: React Router v6
- Forms: React Hook Form + Zod resolver
- Validation: Zod (shared schemas with backend)
- HTTP: native `fetch` via the project API client (not axios)
- Testing: Vitest + React Testing Library + MSW
- E2E: Playwright

**Component rules:**
- Functional only, TypeScript, explicit `interface` props
- Max ~150 lines; split if larger
- Named exports in feature folders; barrel `index.ts`
- Co-located test file `Component.test.tsx`

**State rules:**
- ALL server data via React Query — never `fetch` in `useEffect`
- Never store API responses in Redux/Zustand
- Loading + error + empty states always handled

**Anti-patterns (never do):**
- `any` type
- `console.log` in production code
- `useEffect` for data fetching
- Class components
- Default exports inside feature folders
- Inline `style={{}}` for static values
- Business logic inside component body (goes in a hook)
- CSS overriding third-party components globally
