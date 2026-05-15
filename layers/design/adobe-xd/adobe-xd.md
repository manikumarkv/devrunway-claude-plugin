# Adobe XD Standards

## File Organization

```
XD Document Structure:
├── Cover Page          — project name, version, last updated
├── Design System       — colors, typography, spacing, iconography artboards
├── Components          — all reusable components with states
├── Flows/
│   ├── Auth            — login, signup, forgot-password
│   ├── Onboarding      — step 1-4
│   └── Dashboard       — main views
└── Prototypes          — linked prototype per flow
```

## Component Naming Convention

```
Pattern: Category/Variant/State

Examples:
  Button/Primary/Default
  Button/Primary/Hover
  Button/Primary/Pressed
  Button/Primary/Disabled
  Button/Secondary/Default
  Input/Text/Default
  Input/Text/Focus
  Input/Text/Error
  Card/Product/Default
  Card/Product/Skeleton
  Nav/Top/Collapsed
  Nav/Top/Expanded
```

## Component States Setup

1. Select a component on the artboard
2. Open Component States panel (Window → Component States)
3. Add states: `Default`, `Hover`, `Pressed`, `Disabled`, `Focus`, `Error`
4. For each state, adjust fill, border, text color, shadow — never duplicate artboards
5. Mark the `Default` state as the base state

## Design Tokens Export

Install the **Design Tokens** plugin (Niclas Löbe).

Token structure:
```json
{
  "color": {
    "primary": {
      "50":  { "value": "#EFF6FF", "type": "color" },
      "100": { "value": "#DBEAFE", "type": "color" },
      "500": { "value": "#3B82F6", "type": "color" },
      "900": { "value": "#1E3A8A", "type": "color" }
    },
    "neutral": {
      "0":   { "value": "#FFFFFF", "type": "color" },
      "900": { "value": "#111827", "type": "color" }
    },
    "semantic": {
      "error":   { "value": "{color.red.500}", "type": "color" },
      "success": { "value": "{color.green.500}", "type": "color" }
    }
  },
  "typography": {
    "heading-xl": {
      "fontFamily": { "value": "Inter", "type": "fontFamily" },
      "fontSize":   { "value": "36", "type": "fontSize" },
      "fontWeight": { "value": "700", "type": "fontWeight" },
      "lineHeight": { "value": "1.2", "type": "lineHeight" }
    }
  },
  "spacing": {
    "1": { "value": "4", "type": "spacing" },
    "2": { "value": "8", "type": "spacing" },
    "4": { "value": "16", "type": "spacing" },
    "8": { "value": "32", "type": "spacing" }
  }
}
```

Export flow:
1. Plugins → Design Tokens → Export Tokens
2. Save as `tokens.json` in the repo's `design/` folder
3. Run Style Dictionary to transform into CSS variables, TypeScript constants, etc.

## Style Dictionary Config

```json
{
  "source": ["design/tokens.json"],
  "platforms": {
    "css": {
      "transformGroup": "css",
      "buildPath": "src/styles/",
      "files": [{ "destination": "tokens.css", "format": "css/variables" }]
    },
    "typescript": {
      "transformGroup": "js",
      "buildPath": "src/",
      "files": [{
        "destination": "design-tokens.ts",
        "format": "javascript/es6"
      }]
    }
  }
}
```

## Developer Handoff Checklist

Before publishing a spec link:

- [ ] All layers are semantically named (no `Rectangle 47` or `Group 12`)
- [ ] Export-ready assets have `/` suffix or are marked for export in the Layers panel
- [ ] Spacing uses 4px grid — no arbitrary values
- [ ] Colors reference tokens, not hardcoded hex
- [ ] All component states are defined and linked
- [ ] Accessibility: contrast ratios noted in the spec annotations

## Sharing a Developer Spec

1. File → Publish → Publish for Review/Development
2. Select the artboards/components to include
3. Enable "Allow downloading assets"
4. Copy the link — share this URL, not the `.xd` file
5. Add to the PR description or Jira ticket

## Prototype Links

- One master prototype per feature/flow
- Artboard naming: `[Screen Name] — [State]` e.g., `Checkout — Payment Error`
- Use **Auto-Animate** for state transitions (300ms ease-in-out)
- Use **Slide** or **Dissolve** for screen-to-screen navigation
- Embed the prototype link in the feature ticket before dev starts

## Asset Export Settings

| Asset Type | Format | Resolution |
|---|---|---|
| Icons | SVG | — |
| Illustrations | SVG (vector) or PNG | 1x, 2x |
| Photos | JPEG | 1x, 2x |
| App icons | PNG | 1x, 2x, 3x |

Mark assets for export in the Layers panel (make them exportable), then export from Design → Export Selected.
