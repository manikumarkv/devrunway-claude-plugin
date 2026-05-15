---
name: ant-design
description: Ant Design standards — ConfigProvider, theme tokens, Form with Form.Item, Table, Modal, and global message API
user-invocable: false
stack: ui-components/ant-design
paths:
  - "**/*.tsx"
  - "**/*.ts"
  - "**/*antd*"
  - "**/*ant-design*"
---

Full standards in [ant-design.md](ant-design.md). Always-on summary:

**Setup:**
- Wrap the app with `<ConfigProvider theme={{ token: { colorPrimary: '#1677ff' } }}>` — never rely on the default Ant Design theme
- Use the `theme.useToken()` hook to access design tokens inside components
- Configure locale via `ConfigProvider locale={enUS}` — never mix locales

**Theme customization:**
- Use `algorithm` to switch between `defaultAlgorithm`, `darkAlgorithm`, or `compactAlgorithm`
- Override tokens with `token: { colorPrimary, borderRadius, ... }` — never override via CSS class selectors
- Use `components: { Button: { ... } }` for component-level overrides

**Form:**
- Always use `Form.useForm(` and add validation with `<Form.Item` and `rules={[{ required: true, message: '...' }]}` — never read values via uncontrolled refs
- Pass `form` to `<Form>`; call `form.validateFields()` before submit
- Set `validateTrigger="onBlur"` for long forms to avoid validation noise while typing

**Table:**
- Use `<Table dataSource={records} columns={columnConfig} rowKey="id" />` — typed `ColumnType<RecordType>[]` for columns
- Use server-side pagination: handle `onChange` and track `current`, `pageSize`, `sorter` in state
- Use `rowKey` prop — never rely on array index as key

**Modal:**
- Use `Modal.confirm()` for destructive confirmations — not a custom boolean state toggle
- Use `useModal()` hook (`Modal.useModal()`) in function components for programmatic modals
- Always set `destroyOnClose` to reset form state inside modals

**Never:**
- Never override Ant Design styles with global CSS class selectors — use `ConfigProvider` or `sx`/`style`
- Never use `message.success()` at module level — only inside event handlers or effects
- Never import the entire antd package — use tree-shakeable named imports

**Related skills:** composition-patterns, react-standards, api-conventions
