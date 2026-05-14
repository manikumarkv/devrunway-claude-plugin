---
name: figma-design
description: Figma workflow standards — MCP integration, design token handoff, component naming conventions, dev mode checklist. Load when working with design assets or Figma integration.
user-invocable: false
stack: design/figma
mcp:
  package: "@figma/mcp-server"
  env:
    FIGMA_ACCESS_TOKEN: "figma.com → Account Settings → Personal access tokens → Create new token"
paths:
  - "src/styles/**"
  - "src/tokens/**"
  - "design/**"
  - ".mcp.json"
---

Full standards in [figma-design.md](figma-design.md). Always-on summary:

**MCP:** `claude mcp add figma npx -y @figma/mcp-server` — set `FIGMA_ACCESS_TOKEN` env var first. Use MCP to inspect component specs directly from a Figma URL rather than asking for screenshots.

**Design token naming:** match Tailwind config keys — `color/brand/primary`, `spacing/4`, `radius/md`

**Component naming in Figma:** `ComponentName/Variant/State` → maps to React component + props

**Dev mode checklist before coding:**
- [ ] All interactive states defined (default, hover, focus, disabled, error)
- [ ] Responsive frames present (mobile 375 / tablet 768 / desktop 1440)
- [ ] Design tokens used — no hardcoded hex values
- [ ] Contrast ratio noted (≥ 4.5:1 for normal text)
- [ ] Assets exported (SVG icons, WebP images with 2× fallback)

**Handoff:** link Figma frame in PR description; tag designer before merging visual changes

**Icons:** export as SVG → `src/assets/icons/`; consume as React components via SVGR
