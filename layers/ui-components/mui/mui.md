# Material UI (MUI) Standards

---

## Setup

```bash
npm install @mui/material @emotion/react @emotion/styled @mui/icons-material
```

```typescript
// src/app/layout.tsx (or index.tsx)
import { ThemeProvider } from '@mui/material/styles'
import CssBaseline from '@mui/material/CssBaseline'
import { theme } from './theme'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />   {/* normalises browser styles */}
      {children}
    </ThemeProvider>
  )
}
```

---

## Theme configuration

```typescript
// src/app/theme.ts — single source of truth for all design tokens
import { createTheme, alpha } from '@mui/material/styles'

export const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#1976d2',
      light: '#42a5f5',
      dark: '#1565c0',
      contrastText: '#fff',
    },
    secondary: {
      main: '#9c27b0',
    },
    error: {
      main: '#d32f2f',
    },
    background: {
      default: '#f5f5f5',
      paper: '#fff',
    },
  },

  typography: {
    fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
    h1: { fontSize: '2.5rem', fontWeight: 700 },
    h2: { fontSize: '2rem',   fontWeight: 600 },
    body1: { fontSize: '1rem', lineHeight: 1.5 },
  },

  spacing: 8,   // base spacing unit — theme.spacing(2) = 16px

  shape: {
    borderRadius: 8,
  },

  // Global component overrides
  components: {
    MuiButton: {
      defaultProps: {
        disableElevation: true,
      },
      styleOverrides: {
        root: {
          textTransform: 'none',    // disable all-caps default
          fontWeight: 600,
        },
      },
      variants: [
        {
          props: { variant: 'soft' },   // custom variant
          style: ({ theme }) => ({
            backgroundColor: alpha(theme.palette.primary.main, 0.12),
            color: theme.palette.primary.main,
            '&:hover': {
              backgroundColor: alpha(theme.palette.primary.main, 0.2),
            },
          }),
        },
      ],
    },

    MuiTextField: {
      defaultProps: {
        variant: 'outlined',
        size: 'small',
      },
    },

    MuiCard: {
      defaultProps: {
        elevation: 0,
        variant: 'outlined',
      },
    },
  },
})

// TypeScript: declare custom variants
declare module '@mui/material/Button' {
  interface ButtonPropsVariantOverrides {
    soft: true
  }
}
```

---

## sx prop — one-off styles

```typescript
// Use theme tokens, not hardcoded values
<Box sx={{
  color: 'primary.main',          // theme.palette.primary.main
  bgcolor: 'background.paper',    // theme.palette.background.paper
  p: 2,                           // theme.spacing(2) = 16px
  mb: { xs: 1, md: 2 },          // responsive margin-bottom
  display: 'flex',
  alignItems: 'center',
  gap: 1,
  borderRadius: 1,                // theme.shape.borderRadius
  border: 1,
  borderColor: 'divider',
}} />

// Typography variants
<Typography variant="h2" sx={{ fontWeight: 700 }}>
  Heading
</Typography>

// Conditional styles
<Box sx={{
  opacity: isDisabled ? 0.5 : 1,
  pointerEvents: isDisabled ? 'none' : 'auto',
}} />
```

---

## styled() — reusable styled components

```typescript
import { styled } from '@mui/material/styles'
import Card from '@mui/material/Card'

// Use when sx becomes repetitive across multiple instances
const FeatureCard = styled(Card)(({ theme }) => ({
  padding: theme.spacing(3),
  border: `1px solid ${theme.palette.divider}`,
  borderRadius: theme.spacing(1),
  transition: theme.transitions.create(['border-color', 'box-shadow']),
  '&:hover': {
    borderColor: theme.palette.primary.main,
    boxShadow: `0 0 0 2px ${alpha(theme.palette.primary.main, 0.2)}`,
  },
}))

// With custom props
interface StatusChipProps {
  status: 'active' | 'inactive' | 'pending'
}
const StatusChip = styled(Chip)<StatusChipProps>(({ theme, status }) => ({
  backgroundColor: {
    active:   theme.palette.success.light,
    inactive: theme.palette.error.light,
    pending:  theme.palette.warning.light,
  }[status],
}))
```

---

## Common components

```typescript
// Form field — always use label prop for accessibility
<TextField
  label="Email address"          // visible label + aria-label
  type="email"
  value={email}
  onChange={(e) => setEmail(e.target.value)}
  error={!!errors.email}
  helperText={errors.email}     // shown below field; linked via aria-describedby
  fullWidth
  required
/>

// Button variants
<Button variant="contained">Primary action</Button>
<Button variant="outlined">Secondary action</Button>
<Button variant="text">Tertiary action</Button>
<Button variant="soft">Soft emphasis</Button>   // custom variant from theme

// Loading button
<LoadingButton
  loading={isSubmitting}
  variant="contained"
  type="submit"
>
  Save
</LoadingButton>

// Icon button — always add aria-label
<IconButton aria-label="Close dialog" onClick={onClose}>
  <CloseIcon />
</IconButton>

// Alert
<Alert severity="error" sx={{ mb: 2 }}>
  {errorMessage}
</Alert>
```

---

## Layout components

```typescript
// Stack — flex container with gap
<Stack direction="row" spacing={2} alignItems="center">
  <Avatar src={user.avatar} alt={user.name} />
  <Typography>{user.name}</Typography>
</Stack>

// Grid2 — responsive grid (MUI v6+)
<Grid2 container spacing={2}>
  <Grid2 size={{ xs: 12, md: 6 }}>
    <Card />
  </Grid2>
  <Grid2 size={{ xs: 12, md: 6 }}>
    <Card />
  </Grid2>
</Grid2>

// Box — generic container
<Box
  component="section"   // renders as <section>
  sx={{ py: 4 }}
>
  content
</Box>
```

---

## Dark mode

```typescript
// System preference or user toggle
import { useMediaQuery } from '@mui/material'

function App() {
  const prefersDark = useMediaQuery('(prefers-color-scheme: dark)')
  const [mode, setMode] = useState<'light' | 'dark'>(prefersDark ? 'dark' : 'light')

  const theme = useMemo(() => createTheme({
    palette: { mode },
  }), [mode])

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Button onClick={() => setMode(m => m === 'light' ? 'dark' : 'light')}>
        Toggle theme
      </Button>
    </ThemeProvider>
  )
}
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| `sx={{ color: '#1976d2' }}` | `sx={{ color: 'primary.main' }}` — use theme tokens |
| `makeStyles` or `withStyles` | Use `sx` prop or `styled()` — deprecated in v5 |
| `IconButton` with no `aria-label` | Always add `aria-label` to buttons with no visible text |
| Overriding with CSS `!important` | Use `theme.components` overrides or `sx` prop |
| No `CssBaseline` | Add it to the root — it normalises styles and enables MUI's reset |
| Hardcoded spacing `px` values | `p: 2` = `theme.spacing(2)` = `16px` — use spacing multipliers |
