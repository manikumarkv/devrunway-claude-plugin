---
name: composition-patterns
description: React component architecture patterns — compound components, provider-based state, context interfaces, explicit variants. Load when designing, building, or reviewing React component structure, component APIs, or shared state patterns.
user-invocable: false
---

Full patterns in [patterns.md](patterns.md). Always-on summary:

**Architecture rules:**
- No boolean prop proliferation — use explicit component variants instead
- Complex components → compound components sharing context, not prop drilling
- Children-based composition over `renderX` render props

**State rules:**
- Lift shared state into dedicated provider components
- Define context as three-part interface: `state`, `actions`, `meta`
- UI components consume the interface — never coupled to useState/Zustand/etc.
- Swap the provider, keep the UI

**React 19:**
- No `forwardRef` — accept `ref` as a regular prop
- `use(Context)` instead of `useContext()`


**Related skills — apply together:**
- `react-standards` — performance rules apply inside all composed components
- `typescript-patterns` — type context interfaces, discriminated unions for compound state
- `accessibility` — compound components must preserve keyboard navigation and ARIA roles