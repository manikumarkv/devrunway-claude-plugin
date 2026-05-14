# Figma Design Standards

## MCP Setup

The Figma MCP server lets Claude read design specs directly from Figma URLs without screenshots or manual copy-paste.

```bash
# Add to project MCP config (or let /setup generate .mcp.json)
claude mcp add figma npx -y @figma/mcp-server

# Required env var
export FIGMA_ACCESS_TOKEN="<token from figma.com → Account Settings → Personal access tokens>"
```

Once connected, Claude can use `mcp__figma__*` tools to fetch component specs, styles, and assets directly from a Figma file URL.

## Design Token Conventions

Token naming must match your Tailwind `theme.extend` keys so tokens flow directly into CSS:

| Token category | Format | Example |
|---|---|---|
| Color | `color/<group>/<name>` | `color/brand/primary`, `color/neutral/500` |
| Spacing | `spacing/<value>` | `spacing/4` → `1rem` |
| Border radius | `radius/<size>` | `radius/md` → `0.375rem` |
| Typography | `font/<property>/<name>` | `font/size/lg`, `font/weight/semibold` |
| Shadow | `shadow/<name>` | `shadow/card`, `shadow/dropdown` |

Export tokens from Figma Variables or Tokens Studio → `src/styles/tokens.ts` → import into `tailwind.config.ts`.

## Component Naming

Figma frames use the pattern `ComponentName/Variant/State`:

```
Button/Primary/Default
Button/Primary/Hover
Button/Primary/Disabled
Button/Secondary/Default
UserCard/Compact/Default
UserCard/Expanded/Loading
```

This maps directly to React component + `variant` + state props:
```tsx
<Button variant="primary" disabled={false} />
<UserCard variant="compact" isLoading={false} />
```

If the Figma component name doesn't match a React prop, discuss with designer before building.

## Dev Mode Checklist

Run through this before writing any component code:

### States
- [ ] Default state visible
- [ ] Hover state (cursor:pointer elements)
- [ ] Focus state (keyboard-accessible; must be visible — check WCAG 2.4.7)
- [ ] Active / pressed state
- [ ] Disabled state (if applicable)
- [ ] Error state (for form inputs)
- [ ] Loading / skeleton state (for async content)
- [ ] Empty state (for lists and data views)

### Responsive
- [ ] Mobile frame present (375px or 390px)
- [ ] Tablet frame present (768px) if layout differs
- [ ] Desktop frame present (1440px)
- [ ] Breakpoint behaviour annotated (what collapses/reflows)

### Accessibility
- [ ] Color contrast ≥ 4.5:1 for body text, ≥ 3:1 for large text and UI components
- [ ] Focus indicators visible and high-contrast
- [ ] ARIA role / label annotated for non-semantic elements
- [ ] Touch target size ≥ 44×44px on mobile

### Assets
- [ ] Icons exported as SVG (not PNG)
- [ ] Images exported as WebP with PNG fallback
- [ ] Illustrations at 2× resolution for retina
- [ ] Font weights match system fonts or web font weights available

### Tokens
- [ ] No hardcoded hex values — all colors are design tokens
- [ ] Spacing uses 4px grid (Tailwind spacing scale)
- [ ] Border radius matches token set

## Handoff Workflow

1. **Designer marks frames** `[Dev Ready]` in Figma
2. **Developer links frame** in the PR description: `Figma: https://figma.com/file/...`
3. **Developer implements** and attaches screenshots in the PR
4. **Designer reviews** the screenshots — must approve before merge if visual change
5. **On merge**, designer removes `[Dev Ready]` tag and marks as `[Implemented]`

## Working with Icons

Export pipeline: Figma SVG → `src/assets/icons/` → SVGR React component

```bash
# Install SVGR
npm install --save-dev @svgr/webpack

# Vite config
import svgr from 'vite-plugin-svgr'
export default { plugins: [svgr()] }
```

```tsx
// Usage
import { ReactComponent as ChevronIcon } from '@/assets/icons/chevron.svg'

<ChevronIcon className="w-4 h-4 text-current" aria-hidden="true" />
```

Icon naming: `kebab-case.svg` → React component `PascalCaseIcon`.

Always add `aria-hidden="true"` for decorative icons; add `aria-label` for standalone actionable icons.

## Using Figma MCP with Claude

Ask Claude to fetch specs when you have a Figma URL:

```
"Read the Card component specs from this Figma frame: https://figma.com/file/..."
"What are the color values used in the nav bar in this design?"
"Extract all spacing values from this component"
```

Claude will use `mcp__figma__*` tools to fetch the exact values rather than guessing from a screenshot.
