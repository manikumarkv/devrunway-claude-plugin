---
name: adobe-xd
description: Adobe XD — component states, design tokens, developer handoff specs, prototype links
user-invocable: false
stack: design/adobe-xd
paths:
  - "**/*.xd"
  - "**/design/**"
  - "**/tokens/**"
  - "**/design-tokens*"
---

Full standards in [adobe-xd.md](adobe-xd.md). Always-on summary:

**Component States:**
- Define all interactive states in XD: Default, Hover, Pressed, Disabled, Focus, Error
- Use Component States panel — do not duplicate artboards for states
- Name components with BEM-like convention: `Button/Primary/Default`, `Button/Primary/Hover`

**Design Tokens:**
- Export tokens (colors, typography, spacing) using the Design Tokens plugin
- Token names must match the codebase variable names: `color-primary-500`, `spacing-4`
- Generate a `tokens.json` — import into the codebase via Style Dictionary or Token Transformer

**Developer Handoff:**
- Share designs via XD Share → Developer — not by exporting screenshots
- Annotate every component with measurement specs and asset names
- Mark export-ready assets with the export marker (`/` suffix on layers means exportable)
- Spec spacing in multiples of 4px; font sizes in the approved type scale

**Prototype Links:**
- Link all flows end-to-end before developer handoff
- Use Auto-Animate for transitions — name artboards with the screen state they represent
- Provide a master prototype link per feature, not per individual screen

**Never:**
- Hardcode hex values outside of a defined color token
- Use rasterized images where vector components exist
- Share `.xd` source files directly — use the Share/Publish flow
- Leave unnamed layers (`Rectangle 47`) — all layers must be semantically named

**Related skills:** `accessibility`, `composition-patterns`
