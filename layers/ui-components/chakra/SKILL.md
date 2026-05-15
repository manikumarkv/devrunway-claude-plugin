---
name: chakra
description: Chakra UI standards — ChakraProvider, useColorMode, custom theme, component props, and responsive styles
user-invocable: false
stack: ui-components/chakra
paths:
  - "**/*.tsx"
  - "**/*.ts"
  - "**/*chakra*"
  - "**/*theme*"
---

Full standards in [chakra.md](chakra.md). Always-on summary:

**Setup:**
- Wrap app with `<ChakraProvider theme={customTheme}>` — never use the default theme in production
- Extend the theme with `extendTheme()`; define `colors`, `fonts`, `components`, and `config.initialColorMode`
- Set `config.useSystemColorMode: true` for automatic OS preference detection

**Component usage:**
- Use Chakra's style props (`px`, `py`, `color`, `bg`, `borderRadius`) instead of inline `style={{}}`
- Use semantic tokens (`colorScheme`) for components rather than hardcoded color values
- Prefer `<Stack`, `<HStack>`, `<VStack>`, `<Grid>`, `<Flex>` for layout — not raw `<Box>` + manual flex

**Responsive styles:**
- Use the array syntax for responsive values: `<Box fontSize={["sm", "md", "lg"]}>`
- Or object syntax: `<Box fontSize={{ base: "sm", md: "md", lg: "lg" }}>`
- Breakpoints are `base`, `sm`, `md`, `lg`, `xl`, `2xl` by default

**Color mode:**
- Use `const { colorMode, toggleColorMode } = useColorMode(` for toggle; `useColorModeValue(light, dark)` for conditional values
- Never hardcode colors — use semantic tokens or `useColorModeValue`
- Put `ColorModeScript` in `_document.tsx` to prevent flash of incorrect color mode

**Never:**
- Never use both Chakra and another CSS-in-JS library (styled-components, Emotion) on the same component
- Never override Chakra styles with `!important` — use the `sx` prop or component variants
- Never import from `@chakra-ui/react` and `@chakra-ui/icons` in the same import line

**Related skills:** composition-patterns, react-standards, linting
