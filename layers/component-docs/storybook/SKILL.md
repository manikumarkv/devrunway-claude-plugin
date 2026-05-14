---
name: storybook
description: Storybook 8 standards — CSF3 story format, args, decorators, autodocs, and interaction tests with play(). Load when working with Storybook.
user-invocable: false
stack: component-docs/storybook
paths:
  - "**/*.stories.tsx"
  - "**/*.stories.ts"
  - "**/*.stories.jsx"
  - ".storybook/**"
---

Full standards in [storybook.md](storybook.md). Always-on summary:

**Story format (CSF3):**
- Use Component Story Format 3 (CSF3) — `const Story: Story = { args: { ... } }` not function components
- Export `default` as `Meta<typeof Component>` — Storybook infers arg types from TypeScript props
- Name the file `Component.stories.tsx` co-located with the component

**Args:**
- Use `args` for all configurable props — don't hardcode values in the story render function
- Define `args` at the `default` (Meta) level for shared defaults, override per story
- Use `argTypes` to customise controls (dropdown for enums, color picker for colour props)

**Stories to write:**
- `Default` — the baseline "happy path" story
- Variant stories for each important state: `Loading`, `Empty`, `Error`, `Disabled`
- `AllVariants` — renders all visual variants side-by-side for snapshot testing

**Decorators:**
- Add global decorators in `.storybook/preview.ts` for providers that all stories need (ThemeProvider, Router, QueryClient)
- Keep story-level decorators to a minimum — if every story needs a decorator, it should be global

**Interaction tests (play):**
- Use `play()` with `@storybook/test` (`userEvent`, `expect`) for interaction testing
- Test that a form submits, a modal opens/closes, a button triggers an action
- `play()` functions run in CI via `storybook test` — treat them as part of your test suite

**Autodocs:**
- Add `tags: ['autodocs']` to the Meta to auto-generate documentation
- Write JSDoc comments on your component props — Storybook renders them as prop descriptions

**Never:**
- Hardcode data in story render functions — use `args`
- Import from test utilities in story files — use `@storybook/test` instead
- Skip the `Default` story — it is the baseline and is required for autodocs

**Related skills:** `testing/unit/jest` (unit tests alongside stories), `component-docs/ladle` (lighter alternative)
