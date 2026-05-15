# styled-components Standards

## Install

```bash
npm install styled-components
npm install -D @types/styled-components babel-plugin-styled-components
# or for Next.js with SWC:
npm install -D @swc/plugin-styled-components
```

## Babel config

```json
// .babelrc
{
  "plugins": [
    ["babel-plugin-styled-components", {
      "displayName": true,
      "fileName": true,
      "pure": true
    }]
  ]
}
```

```javascript
// next.config.js (SWC)
/** @type {import('next').NextConfig} */
module.exports = {
  compiler: {
    styledComponents: {
      displayName: true,
      ssr: true,
      fileName: true,
    },
  },
};
```

## Theme definition + TypeScript augmentation

```typescript
// styles/theme.ts
export const theme = {
  colors: {
    primary: {
      50: "#eff6ff",
      500: "#3b82f6",
      600: "#2563eb",
      900: "#1e3a8a",
    },
    neutral: {
      0: "#ffffff",
      100: "#f3f4f6",
      200: "#e5e7eb",
      700: "#374151",
      900: "#111827",
    },
    error: "#ef4444",
    success: "#22c55e",
    warning: "#f59e0b",
  },
  spacing: {
    0: "0",
    1: "0.25rem",
    2: "0.5rem",
    3: "0.75rem",
    4: "1rem",
    6: "1.5rem",
    8: "2rem",
    12: "3rem",
    16: "4rem",
  },
  typography: {
    fontFamily: {
      sans: "'Inter', system-ui, sans-serif",
      mono: "'JetBrains Mono', 'Fira Code', monospace",
    },
    fontSize: {
      xs: "0.75rem",
      sm: "0.875rem",
      base: "1rem",
      lg: "1.125rem",
      xl: "1.25rem",
      "2xl": "1.5rem",
      "3xl": "1.875rem",
    },
    fontWeight: {
      normal: 400,
      medium: 500,
      semibold: 600,
      bold: 700,
    },
    lineHeight: {
      tight: 1.25,
      normal: 1.5,
      relaxed: 1.75,
    },
  },
  breakpoints: {
    sm: "640px",
    md: "768px",
    lg: "1024px",
    xl: "1280px",
  },
  radii: {
    sm: "0.25rem",
    md: "0.5rem",
    lg: "0.75rem",
    full: "9999px",
  },
  shadows: {
    sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
    md: "0 4px 6px -1px rgb(0 0 0 / 0.1)",
    lg: "0 10px 15px -3px rgb(0 0 0 / 0.1)",
  },
} as const;

export type Theme = typeof theme;
```

```typescript
// styles/styled.d.ts — module augmentation for full theme typing
import "styled-components";
import type { Theme } from "./theme";

declare module "styled-components" {
  export interface DefaultTheme extends Theme {}
}
```

## ThemeProvider setup

```tsx
// app/providers.tsx
"use client";
import { ThemeProvider, createGlobalStyle } from "styled-components";
import { theme } from "@/styles/theme";

const GlobalStyle = createGlobalStyle`
  *, *::before, *::after {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }

  html {
    font-size: 16px;
    scroll-behavior: smooth;
  }

  body {
    font-family: ${({ theme }) => theme.typography.fontFamily.sans};
    color: ${({ theme }) => theme.colors.neutral[900]};
    background-color: ${({ theme }) => theme.colors.neutral[0]};
    line-height: ${({ theme }) => theme.typography.lineHeight.normal};
    -webkit-font-smoothing: antialiased;
  }

  a {
    color: ${({ theme }) => theme.colors.primary[600]};
    text-decoration: none;
    &:hover { text-decoration: underline; }
  }
`;

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider theme={theme}>
      <GlobalStyle />
      {children}
    </ThemeProvider>
  );
}
```

## Basic styled components

```typescript
// components/Button/Button.styles.ts
import styled, { css } from "styled-components";

type Variant = "primary" | "secondary" | "ghost" | "danger";
type Size = "sm" | "md" | "lg";

// Use transient props ($variant, $size) — not forwarded to DOM
interface ButtonProps {
  $variant?: Variant;
  $size?: Size;
  $fullWidth?: boolean;
  $loading?: boolean;
}

const sizeStyles = {
  sm: css`
    padding: ${({ theme }) => `${theme.spacing[1]} ${theme.spacing[3]}`};
    font-size: ${({ theme }) => theme.typography.fontSize.sm};
    height: 2rem;
  `,
  md: css`
    padding: ${({ theme }) => `${theme.spacing[2]} ${theme.spacing[4]}`};
    font-size: ${({ theme }) => theme.typography.fontSize.base};
    height: 2.5rem;
  `,
  lg: css`
    padding: ${({ theme }) => `${theme.spacing[3]} ${theme.spacing[6]}`};
    font-size: ${({ theme }) => theme.typography.fontSize.lg};
    height: 3rem;
  `,
};

const variantStyles = {
  primary: css`
    background-color: ${({ theme }) => theme.colors.primary[500]};
    color: ${({ theme }) => theme.colors.neutral[0]};
    border: 2px solid transparent;
    &:hover:not(:disabled) { background-color: ${({ theme }) => theme.colors.primary[600]}; }
    &:focus-visible { outline: 2px solid ${({ theme }) => theme.colors.primary[500]}; outline-offset: 2px; }
  `,
  secondary: css`
    background-color: transparent;
    color: ${({ theme }) => theme.colors.primary[600]};
    border: 2px solid ${({ theme }) => theme.colors.primary[500]};
    &:hover:not(:disabled) { background-color: ${({ theme }) => theme.colors.primary[50]}; }
  `,
  ghost: css`
    background-color: transparent;
    color: ${({ theme }) => theme.colors.neutral[700]};
    border: 2px solid transparent;
    &:hover:not(:disabled) { background-color: ${({ theme }) => theme.colors.neutral[100]}; }
  `,
  danger: css`
    background-color: ${({ theme }) => theme.colors.error};
    color: ${({ theme }) => theme.colors.neutral[0]};
    border: 2px solid transparent;
    &:hover:not(:disabled) { opacity: 0.9; }
  `,
};

export const StyledButton = styled.button<ButtonProps>`
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: ${({ theme }) => theme.spacing[2]};
  border-radius: ${({ theme }) => theme.radii.md};
  font-weight: ${({ theme }) => theme.typography.fontWeight.medium};
  cursor: pointer;
  transition: background-color 150ms ease, opacity 150ms ease, border-color 150ms ease;
  white-space: nowrap;

  ${({ $size = "md" }) => sizeStyles[$size]}
  ${({ $variant = "primary" }) => variantStyles[$variant]}

  ${({ $fullWidth }) => $fullWidth && css`width: 100%;`}

  ${({ $loading }) =>
    $loading &&
    css`
      cursor: wait;
      opacity: 0.7;
      pointer-events: none;
    `}

  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
`;
```

## Component with `attrs()`

```typescript
// components/Input/Input.styles.ts
import styled, { css } from "styled-components";

interface InputProps {
  $hasError?: boolean;
  $size?: "sm" | "md" | "lg";
}

export const StyledInput = styled.input.attrs<InputProps>((props) => ({
  // Default attrs — reduces re-renders compared to passing in JSX
  type: props.type ?? "text",
  autoComplete: props.autoComplete ?? "off",
  spellCheck: false,
}))<InputProps>`
  display: block;
  width: 100%;
  border: 1.5px solid ${({ theme, $hasError }) =>
    $hasError ? theme.colors.error : theme.colors.neutral[200]};
  border-radius: ${({ theme }) => theme.radii.md};
  background-color: ${({ theme }) => theme.colors.neutral[0]};
  color: ${({ theme }) => theme.colors.neutral[900]};
  font-family: inherit;
  transition: border-color 150ms ease, box-shadow 150ms ease;

  ${({ $size = "md", theme }) =>
    ({
      sm: css`padding: ${theme.spacing[1]} ${theme.spacing[2]}; font-size: ${theme.typography.fontSize.sm};`,
      md: css`padding: ${theme.spacing[2]} ${theme.spacing[3]}; font-size: ${theme.typography.fontSize.base};`,
      lg: css`padding: ${theme.spacing[3]} ${theme.spacing[4]}; font-size: ${theme.typography.fontSize.lg};`,
    }[$size])}

  &:focus {
    outline: none;
    border-color: ${({ theme }) => theme.colors.primary[500]};
    box-shadow: 0 0 0 3px ${({ theme }) => theme.colors.primary[50]};
  }

  &::placeholder {
    color: ${({ theme }) => theme.colors.neutral[200]};
  }

  &:disabled {
    background-color: ${({ theme }) => theme.colors.neutral[100]};
    cursor: not-allowed;
  }
`;

export const InputWrapper = styled.div`
  display: flex;
  flex-direction: column;
  gap: ${({ theme }) => theme.spacing[1]};
`;

export const InputLabel = styled.label`
  font-size: ${({ theme }) => theme.typography.fontSize.sm};
  font-weight: ${({ theme }) => theme.typography.fontWeight.medium};
  color: ${({ theme }) => theme.colors.neutral[700]};
`;

export const InputError = styled.span`
  font-size: ${({ theme }) => theme.typography.fontSize.xs};
  color: ${({ theme }) => theme.colors.error};
`;
```

## Responsive helpers

```typescript
// styles/media.ts
import { css } from "styled-components";
import type { Theme } from "./theme";

type Breakpoint = keyof Theme["breakpoints"];

export const media = {
  up: (bp: Breakpoint) => (styles: TemplateStringsArray, ...args: unknown[]) =>
    css`@media (min-width: ${({ theme }: { theme: Theme }) => theme.breakpoints[bp]}) {
      ${css(styles, ...args)}
    }`,
  down: (bp: Breakpoint) => (styles: TemplateStringsArray, ...args: unknown[]) =>
    css`@media (max-width: ${({ theme }: { theme: Theme }) => `calc(${theme.breakpoints[bp]} - 1px)`}) {
      ${css(styles, ...args)}
    }`,
};

// Usage:
const Card = styled.div`
  padding: ${({ theme }) => theme.spacing[4]};

  ${media.up("md")`
    padding: ${({ theme }) => theme.spacing[8]};
    display: grid;
    grid-template-columns: repeat(2, 1fr);
  `}
`;
```

## Extending styled components

```typescript
// Extend a base component without wrapping in a new element
const BaseCard = styled.div`
  border-radius: ${({ theme }) => theme.radii.lg};
  box-shadow: ${({ theme }) => theme.shadows.md};
  padding: ${({ theme }) => theme.spacing[6]};
  background: ${({ theme }) => theme.colors.neutral[0]};
`;

const FeatureCard = styled(BaseCard)`
  border-top: 4px solid ${({ theme }) => theme.colors.primary[500]};
`;

const DangerCard = styled(BaseCard)`
  border: 1.5px solid ${({ theme }) => theme.colors.error};
`;
```

## `useTheme` in non-styled components

```typescript
import { useTheme } from "styled-components";

function Chart() {
  const theme = useTheme();

  return (
    <svg>
      <rect fill={theme.colors.primary[500]} />
    </svg>
  );
}
```

## shouldForwardProp

```typescript
import styled from "styled-components";

// Prevent $isActive from being forwarded to the DOM element
const NavItem = styled.li.withConfig({
  shouldForwardProp: (prop) => !["$isActive", "$indent"].includes(prop),
})<{ $isActive?: boolean; $indent?: number }>`
  background: ${({ theme, $isActive }) =>
    $isActive ? theme.colors.primary[50] : "transparent"};
  padding-left: ${({ theme, $indent = 0 }) =>
    `calc(${theme.spacing[4]} + ${$indent * 1}rem)`};
`;
```

## Common mistakes

| Mistake | Fix |
|---|---|
| Styled component defined inside render | Always define at module level — new class on every render |
| Prop `isActive` forwarded to DOM element | Prefix with `$`: `$isActive`; use transient props |
| Hardcoded hex values | Always reference `theme.colors.*` |
| Inline `style={{}}` for dynamic values | Use props + css interpolation |
| Missing Babel/SWC plugin | Without it: no display names, SSR class mismatch |
| Overloading a styled component with 10+ variants | Extract to a plain function or split into separate components |
| Using `&&` for pseudo selectors | Use `&:hover`, `&:focus` — `&&` increases specificity unnecessarily |
