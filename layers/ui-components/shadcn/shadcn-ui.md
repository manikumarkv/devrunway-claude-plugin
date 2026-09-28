# shadcn/ui Standards

## What is shadcn/ui

shadcn/ui is not an npm package — it's a CLI that copies component source into your repo. Components live at `src/components/ui/` and are fully owned by your project.

## Installing and updating components

```bash
# Install a new component
npx shadcn@latest add button
npx shadcn@latest add dialog form input select table

# Update an existing component (re-copy from latest CLI)
npx shadcn@latest add button --overwrite
```

Never hand-edit files in `src/components/ui/`. Any custom logic goes in wrapper components in `src/shared/components/` or `src/features/<name>/components/`.

## `cn()` for class merging

`cn()` from `src/lib/utils.ts` merges Tailwind classes correctly, resolving conflicts (e.g. `p-2` vs `p-4`). Always use it — never template literals or manual string concatenation.

```ts
// utils.ts
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

```tsx
// Good
<div className={cn('rounded-md p-4', isActive && 'bg-blue-500', className)} />

// Bad — last class wins arbitrarily, conflicts not resolved
<div className={`rounded-md p-4 ${isActive ? 'bg-blue-500' : ''} ${className}`} />
```

## Always forward `className`

Every domain component that wraps a shadcn primitive should accept and forward `className`. This lets callers adjust spacing, width, or other layout concerns without internal changes.

```tsx
interface UserCardProps {
  user: User
  className?: string
}

export function UserCard({ user, className }: UserCardProps) {
  return (
    <Card className={cn('shadow-sm', className)}>
      <CardHeader>
        <CardTitle>{user.name}</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-sm text-muted-foreground">{user.email}</p>
      </CardContent>
    </Card>
  )
}
```

## `cva()` for multi-variant components

Use `cva` (class-variance-authority) for components with multiple visual variants. Export `VariantProps` so callers get type safety.

```tsx
import { cva, type VariantProps } from 'class-variance-authority'

const badgeVariants = cva(
  'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground',
        secondary: 'bg-secondary text-secondary-foreground',
        destructive: 'bg-destructive text-destructive-foreground',
        outline: 'border border-border text-foreground',
      },
    },
    defaultVariants: { variant: 'default' },
  }
)

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />
}
```

## Composing domain components

Build feature-specific components from shadcn primitives. This keeps business logic separate from UI primitives and makes the codebase searchable.

```tsx
// src/features/orders/components/OrderCard.tsx
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'

export function OrderCard({ order }: { order: Order }) {
  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between">
        <CardTitle className="text-base">Order #{order.id}</CardTitle>
        <Badge variant={order.status === 'fulfilled' ? 'default' : 'secondary'}>
          {order.status}
        </Badge>
      </CardHeader>
      <CardContent>...</CardContent>
      <CardFooter>
        <Button variant="outline" size="sm">View details</Button>
      </CardFooter>
    </Card>
  )
}
```

## `asChild` prop

Use `asChild` to render a Radix primitive's interactive behaviour on a different element — most commonly rendering a `Button` as a React Router `Link`.

```tsx
import { Button } from '@/components/ui/button'
import { Link } from 'react-router-dom'

// Renders an <a> with full button styling and behaviour
<Button asChild variant="outline">
  <Link to="/orders/new">New Order</Link>
</Button>
```

## Form integration

Always use the shadcn form wrappers around React Hook Form. They wire up `aria-*` attributes, error display, and label association automatically.

```tsx
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import {
  Form, FormControl, FormField, FormItem, FormLabel, FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'

export function LoginForm() {
  const form = useForm<LoginInput>({
    resolver: zodResolver(LoginSchema),
    defaultValues: { email: '', password: '' },
  })

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Email</FormLabel>
              <FormControl>
                <Input type="email" placeholder="you@example.com" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? 'Signing in…' : 'Sign in'}
        </Button>
      </form>
    </Form>
  )
}
```

## Dialogs

Always control `open` state with React state. Include `aria-describedby` — required for accessible modals.

```tsx
import {
  Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle,
} from '@/components/ui/dialog'

export function DeleteConfirmDialog({ open, onOpenChange, onConfirm }: Props) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent aria-describedby="delete-description">
        <DialogHeader>
          <DialogTitle>Delete item?</DialogTitle>
          <DialogDescription id="delete-description">
            This action cannot be undone.
          </DialogDescription>
        </DialogHeader>
        <div className="flex justify-end gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button variant="destructive" onClick={onConfirm}>Delete</Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}
```

Note: dialogs are only for destructive confirmations. Create/edit forms get their own routes.

## Toast — use Sonner (not the deprecated `useToast` hook)

```bash
# Install via shadcn CLI
npx shadcn@latest add sonner
```

```tsx
// App.tsx — mount Toaster once at the root
import { Toaster } from '@/components/ui/sonner'

function App() {
  return (
    <>
      <RouterProvider router={router} />
      <Toaster position="bottom-right" richColors closeButton />
    </>
  )
}

// In any component — import toast directly from sonner (no hook needed)
import { toast } from 'sonner'

function OrderForm() {
  async function onSubmit(values: FormValues) {
    try {
      await createOrder(values)
      toast.success('Order created', { description: 'Your order is being processed.' })
    } catch {
      toast.error('Failed to create order')
    }
  }
}
```

> The older shadcn built-in `useToast` / `@/components/ui/use-toast` pattern is **deprecated** — do not use it in new code.

## Table — data display

```tsx
import {
  Table, TableBody, TableCell,
  TableHead, TableHeader, TableRow,
} from '@/components/ui/table'

function OrdersTable({ orders }: { orders: Order[] }) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>ID</TableHead>
          <TableHead>Status</TableHead>
          <TableHead className="text-right">Total</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {orders.map(order => (
          <TableRow key={order.id}>
            <TableCell className="font-mono text-sm">{order.id}</TableCell>
            <TableCell><Badge variant="secondary">{order.status}</Badge></TableCell>
            <TableCell className="text-right">${order.total}</TableCell>
          </TableRow>
        ))}
        {orders.length === 0 && (
          <TableRow>
            <TableCell colSpan={3} className="text-center text-muted-foreground py-8">
              No orders yet
            </TableCell>
          </TableRow>
        )}
      </TableBody>
    </Table>
  )
}
```

## Dark mode

shadcn handles dark mode via CSS variables. Toggle the `dark` class on `<html>` using `ThemeProvider`.

```tsx
// App.tsx
import { ThemeProvider } from '@/components/theme-provider'

<ThemeProvider defaultTheme="system" storageKey="ui-theme">
  <App />
</ThemeProvider>
```

Never override CSS variables inline or use `dark:` classes in ways that bypass the theme system.

## Icons

Use `lucide-react` — it ships as a peer dep of shadcn/ui. Import only the icons you use.

```tsx
// Good — tree-shaken, only imports what's needed
import { ChevronDown, Search, User } from 'lucide-react'

// Bad — imports entire icon library
import * as Icons from 'lucide-react'
```

Standard size is `size={16}` (1rem) for inline icons, `size={20}` for standalone.

## Available components — check before building

Before writing any UI, check this list. If it's here, use shadcn — do not roll your own.

| shadcn component | `npx shadcn@latest add` |
|---|---|
| Button, Link button | `button` |
| Text input, Textarea | `input` · `textarea` |
| Checkbox, Radio, Switch | `checkbox` · `radio-group` · `switch` |
| Select dropdown | `select` |
| Date picker | `calendar` · `popover` |
| Form wrapper + validation | `form` |
| Modal / overlay | `dialog` |
| Confirmation dialog | `alert-dialog` |
| Dropdown menu | `dropdown-menu` |
| Context menu | `context-menu` |
| Tabs | `tabs` |
| Accordion | `accordion` |
| Data table | `table` |
| Card | `card` |
| Badge / pill | `badge` |
| Avatar | `avatar` |
| Toast notification | `sonner` |
| Alert banner | `alert` |
| Skeleton loader | `skeleton` |
| Progress bar | `progress` |
| Separator | `separator` |
| Tooltip | `tooltip` |
| Sheet (side panel) | `sheet` |
| Command palette | `command` |
| Breadcrumb | `breadcrumb` |
| Pagination | `pagination` |
