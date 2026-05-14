---
name: shadcn-ui
description: shadcn/ui component patterns — cn() utility, component composition, variant conventions, Radix primitives. Load when working with shadcn/ui components.
user-invocable: false
stack: ui-components/shadcn
paths:
  - "src/components/ui/**"
  - "components/ui/**"
  - "**/*.tsx"
---

Full standards in [shadcn-ui.md](shadcn-ui.md). Always-on summary:

**Components:**
- Live in `src/components/ui/` — never edit them directly; re-run `npx shadcn@latest add <component>` to update
- Always import from `@/components/ui/<name>`, never from `radix-ui` directly

**Styling:**
- `cn()` from `src/lib/utils.ts` for ALL conditional class merging — never string concatenation or template literals
- Always forward `className` prop so callers can override
- Variants: use `cva()` for multi-variant components; export `VariantProps<typeof variants>` as the props type

**Composition:**
- Build domain components by wrapping shadcn primitives — `UserCard` uses `Card`, `CardHeader`, `CardContent`
- `asChild` prop: use when rendering the primitive as a different element (e.g. `<Button asChild><Link .../></Button>`)

**Forms:** always use `FormField` → `FormItem` → `FormLabel` → `FormControl` → `FormMessage` wrappers

**Dialogs:** control open state via React state; always add `aria-describedby` to `DialogContent`

**Toast:** `useToast()` hook only; messages under 80 chars

**Dark mode:** CSS variables + `dark:` class via `ThemeProvider` — don't override per-component

**Icons:** `lucide-react` (peer dep) — import only what you need

**Never:**
- Build a button, input, dialog, select, table, or badge from scratch
- Hand-edit `src/components/ui/` files
- Import from `@radix-ui/*` directly in feature code

**Related skills:** `tailwind-css` (class utilities), `react-standards` (form/modal conventions)
