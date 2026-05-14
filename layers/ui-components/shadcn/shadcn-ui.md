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

## Toast

Use the `useToast()` hook, not direct imports. Keep messages under 80 characters.

```tsx
import { useToast } from '@/components/ui/use-toast'

const { toast } = useToast()

// Success
toast({ title: 'Order created', description: 'Your order #1234 has been placed.' })

// Error
toast({ title: 'Something went wrong', variant: 'destructive' })
```

Mount `<Toaster />` once in `App.tsx` — never per-component.

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
