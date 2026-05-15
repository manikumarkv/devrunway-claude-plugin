# Sketch Standards

## Library Structure

```
Sketch Library File: design-system.sketch
├── 🎨 Colors        — all color swatches as Layer Styles
├── 📝 Typography    — all text styles
├── 🔲 Spacing       — spacing reference artboard (4px grid)
├── 🧩 Symbols/
│   ├── Primitives/
│   │   ├── Icons/         — all icons as symbols
│   │   ├── Avatars/
│   │   └── Badges/
│   ├── Components/
│   │   ├── Buttons/
│   │   │   ├── Primary/Default
│   │   │   ├── Primary/Hover
│   │   │   ├── Primary/Disabled
│   │   │   ├── Secondary/Default
│   │   │   └── ...
│   │   ├── Forms/
│   │   │   ├── Input/Default
│   │   │   ├── Input/Focus
│   │   │   ├── Input/Error
│   │   │   └── ...
│   │   └── Navigation/
│   └── Patterns/
│       ├── Cards/
│       ├── Modals/
│       └── Tables/
```

## Symbol Naming Convention

```
Category/Subcategory/Variant/State

Examples:
  Buttons/Primary/Default
  Buttons/Primary/Hover
  Buttons/Primary/Disabled
  Forms/Input/Text/Default
  Forms/Input/Text/Focus
  Forms/Input/Text/Error
  Navigation/TopBar/Default
  Icons/Arrow/Right
  Icons/Arrow/Left
```

## Symbol Overrides

When using symbols with overrides:
```
✅ DO:
  - Override text content via Text Override
  - Swap nested symbol (e.g., swap icon inside a button)
  - Toggle visibility of optional layers
  - Override image fill

❌ DO NOT:
  - Detach the symbol to change a color
  - Detach to add/remove padding
  - Duplicate a symbol artboard with minor changes (add a new variant instead)
```

## Shared Text Styles

```
Style Name              → CSS Equivalent
──────────────────────────────────────────
Heading/XL/Bold         → font-size: 36px, font-weight: 700, line-height: 1.2
Heading/LG/Bold         → font-size: 30px, font-weight: 700, line-height: 1.25
Heading/MD/SemiBold     → font-size: 24px, font-weight: 600, line-height: 1.3
Body/Base/Regular       → font-size: 16px, font-weight: 400, line-height: 1.5
Body/SM/Regular         → font-size: 14px, font-weight: 400, line-height: 1.5
Body/XS/Regular         → font-size: 12px, font-weight: 400, line-height: 1.4
Label/Base/Medium       → font-size: 14px, font-weight: 500, line-height: 1
```

## Design Tokens with Tokens Studio

1. Install **Tokens Studio for Sketch** plugin
2. Connect to a GitHub repo (JSON token source)
3. Define tokens in the plugin UI or edit `tokens.json` directly:

```json
{
  "global": {
    "color": {
      "primary": {
        "50":  { "$value": "#EFF6FF", "$type": "color" },
        "500": { "$value": "#3B82F6", "$type": "color" },
        "900": { "$value": "#1E3A8A", "$type": "color" }
      }
    },
    "spacing": {
      "1": { "$value": "4", "$type": "spacing" },
      "2": { "$value": "8", "$type": "spacing" },
      "4": { "$value": "16", "$type": "spacing" }
    },
    "borderRadius": {
      "sm": { "$value": "4", "$type": "borderRadius" },
      "md": { "$value": "8", "$type": "borderRadius" }
    }
  }
}
```

4. Apply tokens to Sketch layers via the plugin panel
5. Push token changes to GitHub — Style Dictionary builds into code

## Zeplin Sync

```
Setup:
1. Install Zeplin plugin in Sketch
2. Connect workspace: Plugins → Zeplin → Connect
3. Create a project in Zeplin matching the feature

Sync workflow:
1. Design is ready → Plugins → Zeplin → Export Selected Artboards
2. Enable "Styleguide" sync to push colors + text styles
3. Add the Zeplin project link to the Jira/Linear ticket
4. Annotate complex interactions with Zeplin's note tool

Developer uses:
- Zeplin for measurements, colors, assets
- Never the .sketch file directly
```

## Abstract Versioning

```
Branching model:
  main              ← stable, released designs
  └── feat/checkout ← feature branch
      └── iterations committed with messages like:
          "Add payment method selection step"
          "Refine error states per design review"

Workflow:
1. Create a branch from main in Abstract
2. Open the branch in Sketch via Abstract
3. Make changes → Commit with a descriptive message
4. Open a Review in Abstract → assign reviewer
5. Reviewer requests changes or approves → Merge to main
6. Tag the main branch with the release version

Never:
  - Edit main directly
  - Commit without a descriptive message
  - Merge without a review
```

## Asset Export from Sketch

| Asset Type | Format | Scales |
|---|---|---|
| Icons | SVG | 1x |
| Illustrations | SVG or PNG | 1x, 2x |
| Raster images | PNG | 1x, 2x, 3x |
| App icons | PNG | All sizes via Sketch slices |

Export steps:
1. Mark layers/groups as exportable (+ icon in Layers panel)
2. Set format and scale per asset
3. File → Export… → Export selected

## Pre-Handoff Checklist

- [ ] All new components are Symbols in the Library
- [ ] All colors use Library Layer Styles (no one-off fills)
- [ ] All text uses Library Text Styles
- [ ] Tokens pushed to GitHub and verified in Zeplin styleguide
- [ ] Artboards exported to Zeplin and link added to ticket
- [ ] All layers are named semantically
- [ ] Prototype flow linked (if applicable)
- [ ] Abstract merge review completed before dev start

## Common mistakes

| Mistake | Fix |
|---|---|
| Detaching a symbol to change a color or padding | Never detach; add a new variant or use a Symbol Override instead |
| Using one-off fills instead of Library Layer Styles | All colors must come from a Library Layer Style; local fills break token sync |
| Naming symbols without the `/` hierarchy separator | Use `Buttons/Primary/Default` — the slash creates Sketch's symbol organizer groups |
| Editing `main` directly in Abstract | Always branch from `main`, work in the branch, and open a Review before merging |
| Committing to Abstract without a descriptive message | Write meaningful commit messages like "Add payment error state" so design history is readable |
| Pushing tokens to GitHub without running Style Dictionary | Token changes must be built with Style Dictionary before they appear as CSS/TS constants in code |
| Exporting raster icons instead of SVG | Icons must be SVG; mark them as 1x SVG export in the Layers panel before exporting |
| Sharing the `.sketch` file with developers | Share the Zeplin project link — developers should never open the `.sketch` file directly |
