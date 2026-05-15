---
name: sketch
description: Sketch — symbols, shared styles, design tokens plugin, Zeplin handoff, abstract versioning
user-invocable: false
stack: design/sketch
paths:
  - "**/*.sketch"
  - "**/design/**"
  - "**/sketch/**"
  - "**/tokens/**"
---

Full standards in [sketch.md](sketch.md). Always-on summary:

**Symbols:**
- All reusable UI elements must be Symbols, not duplicated layers
- Name symbols with `/` hierarchy: `Buttons/Primary/Default`, `Forms/Input/Error`
- Use Symbol Overrides for text and image content — never detach a symbol to change content
- Store symbols in a dedicated Library file — not in every project document

**Shared Styles:**
- Define all text and layer styles in the shared Library — never apply one-off styles
- Text style names match the design token: `Heading/XL/Bold`, `Body/Base/Regular`
- Layer styles for colors, borders, and shadows must match token values

**Design Tokens:**
- Use the **Tokens Studio** (formerly Figma Tokens) plugin for Sketch for token management
- Export `tokens.json` to the repo; build into CSS/JS with Style Dictionary
- Token names must be identical across design and code: `color.primary.500`

**Zeplin Handoff:**
- Sync via Zeplin's Sketch plugin before marking a design as ready for dev
- Enable Styleguide sync so Zeplin inherits colors, fonts, and components from the Library
- All screens to be implemented must have a Zeplin link in the ticket

**Abstract Versioning:**
- Commit design changes to Abstract with a descriptive commit message (mirrors Git workflow)
- Create a branch per feature — merge to main via Abstract's review workflow
- Never work directly on the main branch in Abstract

**Never:**
- Detach a Symbol to make a one-off change — override or extend the Symbol instead
- Use non-Library colors or text styles in production designs
- Share `.sketch` files via email or Slack — use Abstract or Zeplin links

**Related skills:** `accessibility`, `composition-patterns`
