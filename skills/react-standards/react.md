# React Standards — Full Reference

## Project Structure
```
src/
├── assets/                    # Static files
├── components/                # Truly shared UI (Button, Modal, Input)
│   └── Button/
│       ├── Button.tsx
│       ├── Button.test.tsx
│       └── index.ts
├── features/                  # Feature modules (one folder per domain)
│   └── orders/
│       ├── api/
│       │   └── orders.api.ts  # React Query hooks for this domain
│       ├── components/
│       │   └── OrderCard/
│       │       ├── OrderCard.tsx
│       │       ├── OrderCard.test.tsx
│       │       └── index.ts
│       ├── hooks/
│       │   └── useOrders.ts   # Business logic hooks
│       ├── types.ts           # Domain types
│       └── index.ts           # Public API of feature
├── hooks/                     # Truly global hooks (useDebounce, useWindowSize)
├── pages/                     # Route-level components (thin, delegate to features)
├── services/                  # API client, auth client
│   └── api.ts                 # Authenticated fetch with Cognito token refresh
├── store/                     # Global state (Zustand stores or Redux slices)
├── types/                     # Shared cross-feature types
├── utils/                     # Pure utility functions (no React)
└── App.tsx
```

## Component Patterns

### Standard component
```tsx
// Good — explicit interface, named export, no business logic
interface UserCardProps {
  userId: string;
  displayName: string;
  onSelect: (id: string) => void;
  isSelected?: boolean;
}

export function UserCard({ userId, displayName, onSelect, isSelected = false }: UserCardProps) {
  return (
    <button
      onClick={() => onSelect(userId)}
      aria-pressed={isSelected}
      className={cn('rounded-lg p-4 border', isSelected && 'border-blue-500')}
    >
      {displayName}
    </button>
  );
}
```

### Component with async data (React Query pattern)
```tsx
// Bad — manual fetch in useEffect
function ProductList() {
  const [products, setProducts] = useState([]);
  useEffect(() => {
    fetch('/api/products').then(r => r.json()).then(setProducts);
  }, []);
  // ...
}

// Good — React Query
function ProductList() {
  const { data: products, isLoading, error } = useProductsQuery();

  if (isLoading) return <ProductListSkeleton />;
  if (error) return <ErrorMessage error={error} />;
  if (!products?.length) return <EmptyState message="No products found" />;

  return (
    <ul>
      {products.map(product => (
        <li key={product.id}><ProductCard product={product} /></li>
      ))}
    </ul>
  );
}
```

## React Query Patterns

### Query hooks (in `features/<name>/api/<name>.api.ts`)
```ts
const KEYS = {
  all: ['products'] as const,
  list: (filters: ProductFilters) => [...KEYS.all, 'list', filters] as const,
  detail: (id: string) => [...KEYS.all, 'detail', id] as const,
};

export function useProductsQuery(filters: ProductFilters) {
  return useQuery({
    queryKey: KEYS.list(filters),
    queryFn: () => api.get<Product[]>(`/products?${toQueryString(filters)}`),
    staleTime: 30_000,
  });
}

export function useProductQuery(id: string) {
  return useQuery({
    queryKey: KEYS.detail(id),
    queryFn: () => api.get<Product>(`/products/${id}`),
    enabled: Boolean(id),
  });
}

export function useCreateProductMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: CreateProductInput) => api.post<Product>('/products', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: KEYS.all });
    },
  });
}
```

## Custom Hooks Pattern

```ts
// features/orders/hooks/useOrderForm.ts
export function useOrderForm(orderId?: string) {
  const { data: order } = useOrderQuery(orderId ?? '', { enabled: Boolean(orderId) });
  const createMutation = useCreateOrderMutation();
  const updateMutation = useUpdateOrderMutation();

  const form = useForm<OrderFormValues>({
    resolver: zodResolver(orderSchema),
    defaultValues: order ?? defaultOrderValues,
  });

  async function handleSubmit(values: OrderFormValues) {
    if (orderId) {
      await updateMutation.mutateAsync({ id: orderId, ...values });
    } else {
      await createMutation.mutateAsync(values);
    }
  }

  return { form, handleSubmit, isLoading: createMutation.isPending || updateMutation.isPending };
}
```

## State Management Rules

| Data type | Solution |
|---|---|
| Server/API data | React Query |
| Local UI state (modal open, tab active) | `useState` |
| Complex local state with transitions | `useReducer` |
| Global UI state (theme, sidebar) | Zustand |
| Complex shared app state with actions | Redux Toolkit |
| Form state | React Hook Form |

**Never put API response data in Zustand or Redux.** It lives in React Query cache.

## Forms with Zod + React Hook Form

```tsx
const loginSchema = z.object({
  email: z.string().email('Invalid email'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});
type LoginValues = z.infer<typeof loginSchema>;

function LoginForm() {
  const { login } = useAuth();
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<LoginValues>({
    resolver: zodResolver(loginSchema),
  });

  return (
    <form onSubmit={handleSubmit(async values => { await login(values); })}>
      <input {...register('email')} type="email" aria-label="Email" aria-invalid={!!errors.email} />
      {errors.email && <span role="alert">{errors.email.message}</span>}
      <input {...register('password')} type="password" aria-label="Password" />
      {errors.password && <span role="alert">{errors.password.message}</span>}
      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Signing in…' : 'Sign In'}
      </button>
    </form>
  );
}
```

## Testing Patterns

```tsx
// OrderCard.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { OrderCard } from './OrderCard';
import { createWrapper } from '@/test/utils'; // React Query + Router wrapper

const mockOrder: Order = { id: '1', status: 'pending', total: 99.99, items: [] };

describe('OrderCard', () => {
  it('renders order details', () => {
    render(<OrderCard order={mockOrder} />, { wrapper: createWrapper() });
    expect(screen.getByText('$99.99')).toBeInTheDocument();
    expect(screen.getByText('Pending')).toBeInTheDocument();
  });

  it('calls onSelect when clicked', async () => {
    const onSelect = vi.fn();
    render(<OrderCard order={mockOrder} onSelect={onSelect} />, { wrapper: createWrapper() });
    await userEvent.click(screen.getByRole('button', { name: /view order/i }));
    expect(onSelect).toHaveBeenCalledWith('1');
  });
});
```

## Approved Libraries

| Category | Library | Notes |
|---|---|---|
| Build | Vite | Not CRA, not Webpack direct |
| UI base | React 18 | Concurrent features enabled |
| Types | TypeScript 5+ strict | |
| Styling | Tailwind CSS + clsx/cn | CSS Modules for complex cases |
| Server state | @tanstack/react-query v5 | |
| Client state | Zustand 4 or Redux Toolkit 2 | |
| Routing | React Router v6 | |
| Forms | React Hook Form + Zod | |
| Icons | Lucide React | |
| Dates | date-fns | Not moment |
| Testing | Vitest + @testing-library/react + MSW | |
| E2E | Playwright | |

## Anti-Patterns Reference

| Anti-pattern | Why wrong | Fix |
|---|---|---|
| `useEffect` for data fetch | Race conditions, no cache, no loading state | React Query |
| `any` type | Defeats TypeScript safety | `unknown` + narrowing or proper type |
| Default export in feature | Harder to refactor, breaks tree-shaking analysis | Named export |
| Business logic in component | Hard to test, bloated component | Extract to hook |
| `console.log` | Left in production | Remove or use structured logger |
| Redux for server data | Duplicates React Query, stale data | React Query only |
| CSS class overrides of 3rd party | Fragile, breaks on updates | Use component API or CSS variables |
