# Storybook 8 Standards

---

## Setup

```bash
npx storybook@latest init   # auto-detects framework
npm install --save-dev @storybook/test @storybook/addon-interactions
```

---

## `.storybook/main.ts`

```typescript
import type { StorybookConfig } from '@storybook/nextjs'  // or @storybook/react-vite

const config: StorybookConfig = {
  stories: ['../src/**/*.stories.@(ts|tsx)'],
  addons: [
    '@storybook/addon-essentials',       // actions, controls, docs, viewport, backgrounds
    '@storybook/addon-interactions',     // play() function UI
    '@storybook/addon-a11y',             // accessibility audit
  ],
  framework: {
    name: '@storybook/nextjs',
    options: {},
  },
  docs: {
    autodocs: 'tag',   // only generates docs when tags: ['autodocs'] is set
  },
  typescript: {
    reactDocgen: 'react-docgen-typescript',
    check: false,    // don't block builds on TS errors in stories
  },
}

export default config
```

---

## `.storybook/preview.ts`

```typescript
import type { Preview } from '@storybook/react'
import { ThemeProvider } from '@mui/material'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { theme } from '../src/theme'
import '../src/styles/globals.css'

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false } },
})

const preview: Preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date:  /Date$/i,
      },
    },
    layout:   'centered',   // center stories by default
    backgrounds: {
      default: 'light',
      values: [
        { name: 'light', value: '#ffffff' },
        { name: 'dark',  value: '#1a1a1a' },
      ],
    },
    actions: { argTypesRegex: '^on[A-Z].*' },   // auto-spy on onXxx props
  },

  // Global decorators — wrap every story
  decorators: [
    (Story) => (
      <QueryClientProvider client={queryClient}>
        <ThemeProvider theme={theme}>
          <MemoryRouter>
            <Story />
          </MemoryRouter>
        </ThemeProvider>
      </QueryClientProvider>
    ),
  ],
}

export default preview
```

---

## CSF3 story format

```tsx
// src/components/Button/Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react'
import { fn } from '@storybook/test'
import { Button } from './Button'

// ── Meta ──────────────────────────────────────────────────────────────────────

const meta = {
  title:      'UI/Button',            // sidebar grouping
  component:  Button,
  tags:       ['autodocs'],           // generate docs page
  parameters: {
    layout: 'centered',
  },
  args: {
    // Default args shared across all stories
    onClick:   fn(),                  // spy — tracked in the Actions panel
    disabled:  false,
    isLoading: false,
  },
  argTypes: {
    variant: {
      control:   { type: 'select' },
      options:   ['primary', 'secondary', 'danger'],
      description: 'Visual style of the button',
    },
    size: {
      control: { type: 'radio' },
      options: ['sm', 'md', 'lg'],
    },
  },
} satisfies Meta<typeof Button>

export default meta
type Story = StoryObj<typeof meta>

// ── Stories ───────────────────────────────────────────────────────────────────

export const Default: Story = {
  args: {
    children: 'Click me',
    variant:  'primary',
    size:     'md',
  },
}

export const Secondary: Story = {
  args: {
    ...Default.args,
    variant: 'secondary',
  },
}

export const Danger: Story = {
  args: {
    ...Default.args,
    variant:  'danger',
    children: 'Delete',
  },
}

export const Loading: Story = {
  args: {
    ...Default.args,
    isLoading: true,
    children:  'Saving…',
  },
}

export const Disabled: Story = {
  args: {
    ...Default.args,
    disabled: true,
  },
}

export const SmallSize: Story = {
  args: {
    ...Default.args,
    size:     'sm',
    children: 'Small',
  },
}

// All variants side-by-side (useful for visual regression)
export const AllVariants: Story = {
  render: () => (
    <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
      <Button variant="primary">Primary</Button>
      <Button variant="secondary">Secondary</Button>
      <Button variant="danger">Danger</Button>
      <Button variant="primary" disabled>Disabled</Button>
      <Button variant="primary" isLoading>Loading</Button>
    </div>
  ),
}
```

---

## Interaction tests (play)

```tsx
// src/components/LoginForm/LoginForm.stories.tsx
import type { Meta, StoryObj } from '@storybook/react'
import { within, userEvent, expect, fn } from '@storybook/test'
import { LoginForm } from './LoginForm'

const meta = {
  title:     'Forms/LoginForm',
  component: LoginForm,
  args: {
    onSuccess: fn(),
    onError:   fn(),
  },
} satisfies Meta<typeof LoginForm>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}

export const FilledIn: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)

    // Fill out the form
    await userEvent.type(canvas.getByLabelText('Email'), 'user@example.com')
    await userEvent.type(canvas.getByLabelText('Password'), 'Secret123!')
  },
}

export const SubmitSuccess: Story = {
  play: async ({ canvasElement, args }) => {
    const canvas = within(canvasElement)

    await userEvent.type(canvas.getByLabelText('Email'), 'user@example.com')
    await userEvent.type(canvas.getByLabelText('Password'), 'Secret123!')
    await userEvent.click(canvas.getByRole('button', { name: /sign in/i }))

    // Verify the success handler was called
    await expect(args.onSuccess).toHaveBeenCalledOnce()
  },
}

export const ValidationErrors: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)

    // Submit without filling in fields
    await userEvent.click(canvas.getByRole('button', { name: /sign in/i }))

    // Verify validation errors appear
    await expect(canvas.getByText('Email is required')).toBeVisible()
    await expect(canvas.getByText('Password is required')).toBeVisible()
  },
}
```

---

## Mocking API calls in stories

```tsx
// Using MSW (Mock Service Worker) with Storybook
// Install: npm install --save-dev msw msw-storybook-addon

// .storybook/preview.ts — add MSW handler
import { initialize, mswLoader } from 'msw-storybook-addon'
initialize()

const preview: Preview = {
  loaders: [mswLoader],
  // ...
}

// In a story:
import { http, HttpResponse } from 'msw'

export const WithData: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/orders', () => {
          return HttpResponse.json({
            data: [
              { id: '1', status: 'pending', total: 49.99 },
              { id: '2', status: 'shipped', total: 129.00 },
            ],
          })
        }),
      ],
    },
  },
}

export const Loading: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/orders', async () => {
          await new Promise(() => {})  // never resolves — shows loading state
        }),
      ],
    },
  },
}

export const ErrorState: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/orders', () => {
          return HttpResponse.json({ error: 'Server error' }, { status: 500 })
        }),
      ],
    },
  },
}
```

---

## Running Storybook

```bash
# Development
npm run storybook          # start at localhost:6006

# Build static version
npm run build-storybook

# Run interaction tests (CI)
npx storybook test         # runs all play() functions

# Run interaction tests with coverage
npx storybook test --coverage
```

---

## Package.json scripts

```json
{
  "scripts": {
    "storybook":       "storybook dev -p 6006",
    "build-storybook": "storybook build",
    "test:storybook":  "storybook test --ci"
  }
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Hardcoding data in story JSX | Use `args` — they show in the Controls panel and can be changed at runtime |
| No `Default` story | Required for autodocs and visual regression baselines |
| Skipping `play()` tests for interactive components | `play()` is your component integration test — write it |
| Importing from `@testing-library/react` in stories | Use `@storybook/test` — same API, runs in the browser |
| Global providers missing from preview.ts | Every story breaks without them — add ThemeProvider, Router, QueryClient globally |
| `autodocs` on every story file | Only add `tags: ['autodocs']` to components that need a docs page |
| Not using `fn()` for event prop spies | Without `fn()`, the Actions panel shows nothing when the prop is called |
