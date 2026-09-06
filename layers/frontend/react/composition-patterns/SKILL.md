---
name: composition-patterns
description: React component architecture patterns — compound components, provider-based state, context interfaces, explicit variants. Load when designing, building, or reviewing React component structure, component APIs, or shared state patterns.
user-invocable: false
stack: frontend/react
paths:
  - "**/components/**"
  - "**/providers/**"
  - "**/context/**"
---

Full patterns in [patterns.md](patterns.md). Always-on summary:

> **Scope — composition only.** This layer shares `**/components/**` with `react-standards`
> (which claims `**/*.tsx`), so both load on the same file. `react-standards` is authoritative
> for the React version, the UI primitive library (shadcn/ui) and forms; this layer is
> authoritative for how components are composed out of those primitives. Where the two overlap,
> follow `react-standards`.
> See `docs/adr/0001-layer-glob-collision-and-dispatcher-routing-policy.md`.

**Architecture rules:**
- No boolean prop proliferation — use explicit component variants instead
- Complex components → compound components sharing context, not prop drilling
- Children-based composition over `renderX` render props — accept `children: React.ReactNode` for flexible slot-based layouts

**Forwarding refs:**
- Use `forwardRef(` to expose the underlying element to parent components
- Forward onto the shadcn primitive, never onto a hand-rolled HTML element — `react-standards`
  forbids building an input, button, dialog, select, table or badge from scratch:
  ```tsx
  import { Input } from '@/components/ui/input'
  import { Label } from '@/components/ui/label'

  const TextInput = forwardRef<HTMLInputElement, TextInputProps>(
    ({ id, label, ...props }, ref) => (
      <div>
        <Label htmlFor={id}>{label}</Label>
        <Input id={id} ref={ref} {...props} />
      </div>
    )
  )
  TextInput.displayName = 'TextInput'
  ```
- Required for focus management, form libraries, and animation

**Context and compound components:**
- `createContext(` for compound component state: `const TabsCtx = createContext<TabsState | null>(null)`
- Consume with `useContext(TabsCtx)` in sub-components — throw if context is null
- Lift shared state into dedicated provider components
- Define context as three-part interface: `state`, `actions`, `meta`
- UI components consume the interface — never coupled to useState/Zustand/etc.
- Swap the provider, keep the UI

**React version — stated once, by `react-standards`:**
- The React version is pinned in the `react-standards` Stack line (currently **React 18**).
  This layer does not restate it and must not contradict it
- So write the React 18 APIs: `forwardRef(`, `useContext(`, `<Context.Provider value={…}>`
- The React 19 equivalents (`ref` as a plain prop, `use(Context)`, `<Context value={…}>`) are
  documented in [patterns.md § React 19 APIs](patterns.md) **for reference only** — do not use
  them unless the `react-standards` Stack line is changed to React 19 first


**Related skills — apply together:**
- `react-standards` — performance rules apply inside all composed components
- `typescript-patterns` — type context interfaces, discriminated unions for compound state
- `accessibility` — compound components must preserve keyboard navigation and ARIA roles