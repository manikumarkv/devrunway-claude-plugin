---
name: styled-components
description: styled-components standards — ThemeProvider, styled function, css helper, createGlobalStyle, transient props, and attrs
user-invocable: false
stack: css/styled-components
paths:
  - "**/*.tsx"
  - "**/*.ts"
  - "**/*.jsx"
  - "**/*.js"
  - "**/*styled*"
  - "**/*theme*"
---

Full standards in [styled-components.md](styled-components.md). Always-on summary:

**Theme:**
- Wrap the app once with `ThemeProvider`; type the theme with module augmentation so `props.theme` is fully typed
- Define all design tokens (colors, spacing, font sizes, breakpoints) in the theme object — never hardcode hex/px values
- Use `useTheme()` hook to access theme in non-styled components

**Styling:**
- Use the `css` helper for conditional style blocks — it enables syntax highlighting and keeps template literals readable
- Use transient props (`$propName`) to pass styling flags without leaking them to the DOM
- Use `attrs()` to set default HTML attributes and reduce render overhead

**Global styles:**
- Use `createGlobalStyle` for resets and base styles; mount it once in the app shell
- Never use inline styles or a `<style>` tag when a styled component or `createGlobalStyle` would work

**Performance:**
- Add the Babel plugin (`babel-plugin-styled-components`) or the SWC plugin for display names and SSR support
- Use `shouldForwardProp` on elements that receive many custom props to avoid React DOM warnings
- Avoid creating styled components inside render — always define them at module level

**Never:**
- Never interpolate functions that depend on component state inside a styled component — use props properly
- Never mix CSS-in-JS with plain `.css` files for the same component — pick one
- Never create a styled component that is only used once inline — just use the `style` prop or a wrapper component

**Related skills:** composition-patterns, react-standards, linting
