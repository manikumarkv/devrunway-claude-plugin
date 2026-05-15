# Ladle Standards

---

## Setup

```bash
npm install --save-dev @ladle/react
```

```json
// package.json
{
  "scripts": {
    "ladle":       "ladle serve",
    "ladle:build": "ladle build",
    "ladle:preview": "ladle preview"
  }
}
```

---

## Configuration

```javascript
// .ladle/config.mjs
/** @type {import('@ladle/react').UserConfig} */
export default {
  stories:      'src/**/*.stories.{tsx,ts}',
  port:         61000,
  defaultStory: 'components-button--default',
  addons: {
    // Enable/disable built-in addons
    theme:    { enabled: true, defaultState: 'light' },
    a11y:     { enabled: true },
    width:    { enabled: true, options: [375, 768, 1280, 0], defaultState: 768 },
    rtl:      { enabled: false },
    source:   { enabled: true },
  },
}
```

---

## Global providers

```tsx
// .ladle/components.tsx — wraps every story; used for theme providers, router, i18n, etc.
import type { GlobalProvider } from '@ladle/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ThemeProvider } from '@/components/ThemeProvider'

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false, staleTime: Infinity } },
})

export const Provider: GlobalProvider = ({ children, globalState }) => (
  <QueryClientProvider client={queryClient}>
    <ThemeProvider theme={globalState.theme === 'dark' ? 'dark' : 'light'}>
      {children}
    </ThemeProvider>
  </QueryClientProvider>
)
```

---

## Story format (CSF)

```tsx
// src/components/Button/Button.stories.tsx
import type { StoryDefault, Story } from '@ladle/react'
import { Button, type ButtonProps } from './Button'

// Meta — title becomes the navigation path
export default {
  title:     'Components/Button',
  component: Button,
  argTypes: {
    variant:  { control: { type: 'select' }, options: ['primary', 'secondary', 'danger'] },
    size:     { control: { type: 'radio' },  options: ['sm', 'md', 'lg'] },
    disabled: { control: 'boolean' },
    onClick:  { action: true },     // logs clicks in the actions panel
  },
  args: {
    // Shared defaults for all stories in this file
    variant: 'primary',
    size:    'md',
  },
} satisfies StoryDefault<ButtonProps>

type Story = Story<ButtonProps>

// Default story
export const Default: Story = {
  args: {
    children: 'Click me',
  },
}

// Variant stories
export const Secondary: Story = {
  args: { variant: 'secondary', children: 'Cancel' },
}

export const Danger: Story = {
  args: { variant: 'danger', children: 'Delete account' },
}

export const Disabled: Story = {
  args: { disabled: true, children: 'Unavailable' },
}

// Custom render for complex composition
export const WithIcon: Story = {
  args: { children: 'Save' },
  render: (args) => (
    <Button {...args}>
      <svg aria-hidden="true" />
      {args.children}
    </Button>
  ),
}

// Loading state simulation
export const Loading: Story = {
  render: () => <Button variant="primary" disabled aria-busy="true">Saving…</Button>,
}
```

---

## Async stories with data fetching

```tsx
// src/features/orders/OrderList.stories.tsx
import type { StoryDefault, Story } from '@ladle/react'
import { OrderList } from './OrderList'
import { mockOrders } from '@/__fixtures__/orders'

export default {
  title: 'Features/OrderList',
} satisfies StoryDefault

export const WithOrders: Story = {
  render: () => <OrderList orders={mockOrders} />,
}

export const Empty: Story = {
  render: () => <OrderList orders={[]} />,
}

export const Loading: Story = {
  render: () => <OrderList orders={null} isLoading />,
}

export const ErrorState: Story = {
  render: () => <OrderList orders={null} error="Failed to load orders" />,
}
```

---

## Shared fixtures

```typescript
// src/__fixtures__/orders.ts — shared between stories and unit tests
import { faker } from '@faker-js/faker'

export const mockOrder = {
  id:        'order-1',
  status:    'pending' as const,
  total:     99.99,
  createdAt: '2024-01-15T10:30:00Z',
  items:     [
    { id: 'item-1', name: 'Widget Pro', quantity: 2, price: 29.99 },
    { id: 'item-2', name: 'Gadget Lite', quantity: 1, price: 40.01 },
  ],
}

export const mockOrders = Array.from({ length: 5 }, (_, i) => ({
  ...mockOrder,
  id:    `order-${i + 1}`,
  total: faker.number.float({ min: 10, max: 500, fractionDigits: 2 }),
}))
```

---

## CI — build static site for visual review

```yaml
# .github/workflows/ladle.yml
- name: Build Ladle
  run: npm run ladle:build

- name: Deploy to Vercel (preview)
  uses: amondnet/vercel-action@v25
  with:
    vercel-token: ${{ secrets.VERCEL_TOKEN }}
    vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
    vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
    working-directory: ./build/ladle   # ladle build output directory
```

---

## Vite path aliases in stories

```typescript
// vite.config.ts — aliases work automatically in Ladle (it uses the same Vite config)
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
  },
})
```

---

## Accessibility testing in CI

```bash
# @axe-core/cli for static accessibility audit of the built stories
npm install --save-dev @axe-core/cli

# Audit all rendered stories
npx ladle build && npx axe http://localhost:61000 --exit
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Business logic in stories | Stories are visual documentation — extract logic to the component or service layer |
| Hard-coded props instead of args | Use `args` so the controls panel lets reviewers interact with the story |
| Long relative imports in stories | Configure Vite path aliases once in `vite.config.ts` — aliases work in Ladle out of the box |
| One story file per prop combination | Group by component/feature; use `argTypes` + `args` for variations |
| Not providing global providers | Wrap in `.ladle/components.tsx` once — avoids repeating provider boilerplate in every story |
| Skipping `ladle build` in CI | Build the static site and deploy for async visual review by the team |
