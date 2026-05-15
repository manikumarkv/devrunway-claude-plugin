# Chakra UI Standards

## Install

```bash
npm install @chakra-ui/react @emotion/react @emotion/styled framer-motion
# Icons (optional)
npm install @chakra-ui/icons
```

## Custom theme

```typescript
// styles/theme.ts
import { extendTheme, type ThemeConfig } from "@chakra-ui/react";

const config: ThemeConfig = {
  initialColorMode: "system",
  useSystemColorMode: true,
};

export const theme = extendTheme({
  config,
  colors: {
    brand: {
      50: "#eff6ff",
      100: "#dbeafe",
      200: "#bfdbfe",
      300: "#93c5fd",
      400: "#60a5fa",
      500: "#3b82f6",
      600: "#2563eb",
      700: "#1d4ed8",
      800: "#1e40af",
      900: "#1e3a8a",
    },
  },
  fonts: {
    heading: "'Inter', sans-serif",
    body: "'Inter', sans-serif",
    mono: "'JetBrains Mono', monospace",
  },
  fontSizes: {
    xs: "0.75rem",
    sm: "0.875rem",
    md: "1rem",
    lg: "1.125rem",
    xl: "1.25rem",
    "2xl": "1.5rem",
    "3xl": "1.875rem",
    "4xl": "2.25rem",
  },
  space: {
    px: "1px",
    0.5: "0.125rem",
    1: "0.25rem",
    2: "0.5rem",
    3: "0.75rem",
    4: "1rem",
    5: "1.25rem",
    6: "1.5rem",
    8: "2rem",
    10: "2.5rem",
    12: "3rem",
    16: "4rem",
  },
  radii: {
    none: "0",
    sm: "0.25rem",
    md: "0.5rem",
    lg: "0.75rem",
    xl: "1rem",
    full: "9999px",
  },
  components: {
    Button: {
      defaultProps: {
        colorScheme: "brand",
      },
      variants: {
        solid: {
          _focus: {
            boxShadow: "0 0 0 3px var(--chakra-colors-brand-300)",
          },
        },
      },
    },
    Input: {
      defaultProps: {
        focusBorderColor: "brand.500",
      },
    },
    Select: {
      defaultProps: {
        focusBorderColor: "brand.500",
      },
    },
  },
  semanticTokens: {
    colors: {
      "chakra-body-bg": { default: "white", _dark: "gray.900" },
      "chakra-body-text": { default: "gray.800", _dark: "whiteAlpha.900" },
      "card-bg": { default: "white", _dark: "gray.800" },
      "border-color": { default: "gray.200", _dark: "gray.700" },
    },
  },
});
```

## Provider setup

```tsx
// app/providers.tsx
"use client";
import { ChakraProvider } from "@chakra-ui/react";
import { theme } from "@/styles/theme";

export function Providers({ children }: { children: React.ReactNode }) {
  return <ChakraProvider theme={theme}>{children}</ChakraProvider>;
}
```

```tsx
// pages/_document.tsx (Next.js Pages Router — prevent FOICM)
import { ColorModeScript } from "@chakra-ui/react";
import { Html, Head, Main, NextScript } from "next/document";
import { theme } from "@/styles/theme";

export default function Document() {
  return (
    <Html lang="en">
      <Head />
      <body>
        <ColorModeScript initialColorMode={theme.config.initialColorMode} />
        <Main />
        <NextScript />
      </body>
    </Html>
  );
}
```

## Layout patterns

```tsx
// Prefer Stack/HStack/VStack/Grid over raw Box + flex/grid
import { Box, Flex, Grid, GridItem, HStack, VStack, Stack, Divider } from "@chakra-ui/react";

// Card layout
function FeatureCard({ title, description }: { title: string; description: string }) {
  return (
    <Box
      bg="card-bg"
      borderWidth="1px"
      borderColor="border-color"
      borderRadius="lg"
      p={6}
      shadow="sm"
      _hover={{ shadow: "md", transform: "translateY(-2px)" }}
      transition="all 150ms ease"
    >
      <VStack align="start" spacing={3}>
        <Text fontWeight="semibold" fontSize="lg">{title}</Text>
        <Divider />
        <Text color="gray.600" _dark={{ color: "gray.400" }}>{description}</Text>
      </VStack>
    </Box>
  );
}

// Responsive grid
function FeatureGrid({ features }: { features: Array<{ title: string; description: string }> }) {
  return (
    <Grid
      templateColumns={{ base: "1fr", md: "repeat(2, 1fr)", lg: "repeat(3, 1fr)" }}
      gap={{ base: 4, md: 6, lg: 8 }}
    >
      {features.map((f) => (
        <GridItem key={f.title}>
          <FeatureCard {...f} />
        </GridItem>
      ))}
    </Grid>
  );
}
```

## Color mode

```tsx
import {
  useColorMode,
  useColorModeValue,
  IconButton,
} from "@chakra-ui/react";
import { MoonIcon, SunIcon } from "@chakra-ui/icons";

// Toggle button
function ColorModeToggle() {
  const { colorMode, toggleColorMode } = useColorMode();
  return (
    <IconButton
      aria-label={colorMode === "light" ? "Switch to dark mode" : "Switch to light mode"}
      icon={colorMode === "light" ? <MoonIcon /> : <SunIcon />}
      onClick={toggleColorMode}
      variant="ghost"
    />
  );
}

// Conditional values
function ThemedCard() {
  const bg = useColorModeValue("white", "gray.800");
  const borderColor = useColorModeValue("gray.200", "gray.700");
  const textColor = useColorModeValue("gray.800", "whiteAlpha.900");

  return (
    <Box bg={bg} borderColor={borderColor} borderWidth="1px" color={textColor} p={6} borderRadius="lg">
      Content
    </Box>
  );
}
```

## Form with validation

```tsx
import {
  FormControl,
  FormLabel,
  FormErrorMessage,
  FormHelperText,
  Input,
  Button,
  VStack,
  useToast,
} from "@chakra-ui/react";
import { useForm, type SubmitHandler } from "react-hook-form";

interface LoginFormValues {
  email: string;
  password: string;
}

export function LoginForm({ onSuccess }: { onSuccess: () => void }) {
  const toast = useToast();
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormValues>();

  const onSubmit: SubmitHandler<LoginFormValues> = async (data) => {
    try {
      await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });
      toast({ title: "Logged in!", status: "success", duration: 3000, isClosable: true });
      onSuccess();
    } catch {
      toast({ title: "Login failed", status: "error", duration: 5000, isClosable: true });
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <VStack spacing={4} align="stretch">
        <FormControl isInvalid={!!errors.email} isRequired>
          <FormLabel>Email</FormLabel>
          <Input
            type="email"
            placeholder="you@example.com"
            {...register("email", {
              required: "Email is required",
              pattern: { value: /^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "Invalid email" },
            })}
          />
          <FormErrorMessage>{errors.email?.message}</FormErrorMessage>
        </FormControl>

        <FormControl isInvalid={!!errors.password} isRequired>
          <FormLabel>Password</FormLabel>
          <Input
            type="password"
            {...register("password", {
              required: "Password is required",
              minLength: { value: 8, message: "Minimum 8 characters" },
            })}
          />
          <FormHelperText>At least 8 characters.</FormHelperText>
          <FormErrorMessage>{errors.password?.message}</FormErrorMessage>
        </FormControl>

        <Button type="submit" isLoading={isSubmitting} loadingText="Signing in…" w="full">
          Sign in
        </Button>
      </VStack>
    </form>
  );
}
```

## Modal pattern

```tsx
import {
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalCloseButton,
  ModalBody,
  ModalFooter,
  Button,
  useDisclosure,
} from "@chakra-ui/react";

export function ConfirmDeleteModal({
  itemName,
  onConfirm,
}: {
  itemName: string;
  onConfirm: () => Promise<void>;
}) {
  const { isOpen, onOpen, onClose } = useDisclosure();

  async function handleConfirm() {
    await onConfirm();
    onClose();
  }

  return (
    <>
      <Button colorScheme="red" variant="ghost" onClick={onOpen}>
        Delete
      </Button>

      <Modal isOpen={isOpen} onClose={onClose} isCentered>
        <ModalOverlay />
        <ModalContent>
          <ModalHeader>Delete {itemName}?</ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            This action cannot be undone. Are you sure you want to delete <strong>{itemName}</strong>?
          </ModalBody>
          <ModalFooter gap={3}>
            <Button variant="ghost" onClick={onClose}>Cancel</Button>
            <Button colorScheme="red" onClick={handleConfirm}>Delete</Button>
          </ModalFooter>
        </ModalContent>
      </Modal>
    </>
  );
}
```

## Component variants (custom)

```typescript
// In theme.ts — define component variants centrally
components: {
  Badge: {
    variants: {
      "status-active": {
        bg: "green.100",
        color: "green.800",
        _dark: { bg: "green.900", color: "green.200" },
        borderRadius: "full",
        px: 2,
        py: 0.5,
        fontSize: "xs",
        fontWeight: "semibold",
      },
      "status-inactive": {
        bg: "gray.100",
        color: "gray.600",
        _dark: { bg: "gray.700", color: "gray.300" },
        borderRadius: "full",
        px: 2,
        py: 0.5,
        fontSize: "xs",
      },
    },
  },
},

// Usage in component
<Badge variant="status-active">Active</Badge>
```

## `sx` prop for one-off overrides

```tsx
// Use sx instead of inline style or CSS classes
<Box
  sx={{
    "& > * + *": { marginTop: "0.5rem" },
    ".prose h2": { fontSize: "1.5rem", fontWeight: 700 },
  }}
>
  {children}
</Box>
```

## Common mistakes

| Mistake | Fix |
|---|---|
| No custom theme — using default | `extendTheme()` and pass to `ChakraProvider` |
| Hardcoded colors in props | Use `colorScheme="brand"` or `useColorModeValue()` |
| Missing `ColorModeScript` in `_document` | Add it before `<Main />` to prevent FOICM |
| `!important` in sx to override Chakra | Use component variants or `sx` specificity selectors |
| `<Box display="flex" flexDir="column">` for everything | Use `<VStack>`, `<HStack>`, `<Stack>` — they're cleaner |
| Responsive via CSS media queries | Use Chakra's responsive array/object syntax |
| Importing from both `@chakra-ui/react` and `@chakra-ui/icons` in one line | Keep separate imports; tree-shaking works better |
| Rendering toast in render function | Use `useToast()` hook; call `toast()` in event handlers only |
