# React Composition Patterns

Source: Vercel Engineering agent-skills — composition-patterns

> **React version and UI primitives are owned by `react-standards`.** It pins the stack
> (currently React 18) and mandates shadcn/ui for every input, button, dialog, select, table
> and badge. Every example below is written for that pin and imports primitives from
> `@/components/ui/`. § React 19 APIs at the end is reference material for the day the pin
> moves — not guidance to follow today.

---

## Component Architecture — CRITICAL

### Avoid boolean prop proliferation — use explicit variants

Every boolean flag doubles the number of possible component states. Four flags = 16 possible states. This becomes unmanageable fast.

```tsx
// ❌ — each flag adds exponential complexity
interface ComposerProps {
  isThread?: boolean
  isDMThread?: boolean
  isEditing?: boolean
  isForwarding?: boolean
}
function Composer({ isThread, isDMThread, isEditing, isForwarding }: ComposerProps) {
  return (
    <div>
      {isThread && <ThreadHeader />}
      {isDMThread && <DMHeader />}
      <Input />
      {isEditing ? <EditActions /> : isForwarding ? <ForwardActions /> : <DefaultActions />}
    </div>
  )
}

// ✅ — each variant is explicit and self-documenting
function ChannelComposer() {
  return <div><Input /><DefaultActions /></div>
}
function ThreadComposer() {
  return <div><ThreadHeader /><Input /><DefaultActions /></div>
}
function EditComposer({ messageId }: { messageId: string }) {
  return <div><Input /><EditActions messageId={messageId} /></div>
}
function ForwardComposer({ messageId }: { messageId: string }) {
  return <div><Input /><ForwardActions messageId={messageId} /></div>
}
```

### Compound components — shared context, not prop drilling

Structure complex components so subcomponents access shared state via context, not through props passed down from a parent.

```tsx
// ❌ — state and callbacks prop-drilled through every layer
function Composer({ value, onChange, onSubmit, isSubmitting, error }) {
  return (
    <div>
      <ComposerInput value={value} onChange={onChange} error={error} />
      <ComposerFooter onSubmit={onSubmit} isSubmitting={isSubmitting} />
    </div>
  )
}

// ✅ — compound components share context
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'

interface ComposerContextValue {
  value: string
  onChange: (value: string) => void
  onSubmit: () => void
  isSubmitting: boolean
  error: string | null
}

const ComposerContext = createContext<ComposerContextValue | null>(null)

function useComposer() {
  const ctx = useContext(ComposerContext)
  if (!ctx) throw new Error('Must be used within Composer')
  return ctx
}

function ComposerInput() {
  const { value, onChange, error } = useComposer()
  return (
    <>
      <Textarea value={value} onChange={e => onChange(e.target.value)} />
      {error && <span>{error}</span>}
    </>
  )
}

function ComposerFooter() {
  const { onSubmit, isSubmitting } = useComposer()
  return <Button onClick={onSubmit} disabled={isSubmitting}>Send</Button>
}

function ComposerProvider({ children }: { children: React.ReactNode }) {
  const [value, setValue] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const onSubmit = async () => {
    setIsSubmitting(true)
    try { await sendMessage(value); setValue('') }
    catch (e) { setError('Failed to send') }
    finally { setIsSubmitting(false) }
  }

  return (
    <ComposerContext.Provider value={{ value, onChange: setValue, onSubmit, isSubmitting, error }}>
      {children}
    </ComposerContext.Provider>
  )
}

// Export as compound object
export const Composer = {
  Provider: ComposerProvider,
  Input: ComposerInput,
  Footer: ComposerFooter,
}

// Usage — consumer composes exactly what it needs
function ChannelPage() {
  return (
    <Composer.Provider>
      <Composer.Input />
      <Composer.Footer />
    </Composer.Provider>
  )
}
```

---

## State Management — HIGH IMPACT

### Lift state into provider components

State trapped inside a component is inaccessible to siblings. Move it into a provider that wraps all components that need it.

```tsx
// ❌ — siblings can't access composer state
function Page() {
  return (
    <div>
      <Composer />           {/* owns its own state */}
      <ForwardButton />      {/* can't call composer's submit */}
    </div>
  )
}

// ✅ — state lives in provider; any child can access it
function Page() {
  return (
    <ComposerProvider>
      <div>
        <Composer.Input />
        <Sidebar>
          <ForwardButton />  {/* inside provider — can call submit */}
        </Sidebar>
      </div>
    </ComposerProvider>
  )
}
```

Key insight: **components sharing state don't need to be visually nested inside each other — they just need to be within the same provider.**

### Define a three-part context interface

Structure context as `state` + `actions` + `meta`. This makes the contract explicit and enables multiple providers implementing the same interface.

```tsx
// The interface — not coupled to any implementation
interface ComposerState {
  value: string
  attachments: Attachment[]
  error: string | null
}

interface ComposerActions {
  setValue: (value: string) => void
  addAttachment: (file: File) => void
  submit: () => Promise<void>
  reset: () => void
}

interface ComposerMeta {
  inputRef: React.RefObject<HTMLTextAreaElement>
  isSubmitting: boolean
  isDirty: boolean
}

interface ComposerContextValue {
  state: ComposerState
  actions: ComposerActions
  meta: ComposerMeta
}
```

### Decouple UI from state implementation — swap the provider, keep the UI

UI components consume the interface. The provider is the only place that knows how state is managed.

```tsx
// ✅ — UI component: knows nothing about state implementation
function ComposerInput() {
  const { state, actions } = useComposer()
  return (
    <Textarea
      value={state.value}
      onChange={e => actions.setValue(e.target.value)}
    />
  )
}

// Provider A: local ephemeral state (e.g. new message form)
function NewMessageProvider({ children }: { children: React.ReactNode }) {
  const [value, setValue] = useState('')
  const submit = async () => { await sendMessage(value); setValue('') }
  // ...provides ComposerContextValue
  return <ComposerContext.Provider value={...}>{children}</ComposerContext.Provider>
}

// Provider B: globally synced state (e.g. editing a draft)
function DraftProvider({ draftId, children }: { draftId: string; children: React.ReactNode }) {
  const draft = useDraft(draftId)  // synced to server
  const submit = async () => publishDraft(draftId)
  // ...same interface, different implementation
  return <ComposerContext.Provider value={...}>{children}</ComposerContext.Provider>
}

// Same UI, different providers — no UI changes needed
<NewMessageProvider><ComposerInput /></NewMessageProvider>
<DraftProvider draftId="abc"><ComposerInput /></DraftProvider>
```

---

## Implementation Patterns — MEDIUM

### Children over render props

Children compose naturally and don't require understanding a callback signature.

```tsx
// ❌ — render props: awkward signature, hard to read
function Composer({ renderInput, renderFooter }: {
  renderInput: (value: string, onChange: (v: string) => void) => React.ReactNode
  renderFooter: (onSubmit: () => void) => React.ReactNode
}) {
  const [value, setValue] = useState('')
  return (
    <div>
      {renderInput(value, setValue)}
      {renderFooter(handleSubmit)}
    </div>
  )
}

// Usage is awkward
<Composer
  renderInput={(value, onChange) => <Textarea value={value} onChange={e => onChange(e.target.value)} />}
  renderFooter={(onSubmit) => <Button onClick={onSubmit}>Send</Button>}
/>

// ✅ — children + compound components: natural, readable
<Composer.Provider>
  <Composer.Input />
  <Composer.Footer />
</Composer.Provider>
```

When to use render props: only when the parent must pass **dynamic runtime data** back to the child (e.g. virtualised list passing row index).

```tsx
// Legitimate render prop use — parent has data the child needs
<VirtualList
  items={items}
  renderItem={(item, index) => <Row key={item.id} item={item} index={index} />}
/>
```

### Create explicit component variants

Named variants make intent unmistakable and eliminate hidden conditionals.

```tsx
// ❌ — caller must understand prop combinations
<Composer isThread channelId="abc" />
<Composer isEditing messageId="xyz" />
<Composer isForwarding messageId="123" />

// ✅ — each variant wraps the right provider and UI
function ThreadComposer({ channelId }: { channelId: string }) {
  return (
    <ThreadComposerProvider channelId={channelId}>
      <ThreadHeader />
      <Composer.Input />
      <Composer.Footer />
    </ThreadComposerProvider>
  )
}

function EditComposer({ messageId }: { messageId: string }) {
  return (
    <EditComposerProvider messageId={messageId}>
      <Composer.Input />
      <EditActions />
    </EditComposerProvider>
  )
}
```

Each variant:
- Is explicit about what it renders
- Prevents impossible states (EditComposer can never accidentally be a thread)
- Self-documents — the name tells you everything

---

## Forwarding refs

A parent needs the underlying element for focus management, form libraries (React Hook Form
registers a ref) and animation. On the pinned React 18 that means `forwardRef(`.

Forward onto the **shadcn primitive**, never onto a hand-rolled element — `react-standards`
forbids building an input, button, dialog, select, table or badge from scratch, and a raw
element here would drift from the design system and lose its focus and invalid states.

```tsx
// ❌ — hand-rolled element: no design-system styling, no shadcn a11y wiring
const TextInput = forwardRef<HTMLInputElement, TextInputProps>(
  ({ label, ...props }, ref) => <>{label}<HandRolledField ref={ref} {...props} /></>
)

// ❌ — a custom `inputRef` prop instead of a forwarded ref: form libraries and
//      focus helpers pass `ref`, so they cannot reach the element at all
function TextInput({ inputRef, label, ...props }: TextInputProps) {
  return <Input ref={inputRef} {...props} />
}

// ✅ — forwardRef onto the shadcn primitive
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

interface TextInputProps extends React.ComponentPropsWithoutRef<typeof Input> {
  id: string
  label: string
}

const TextInput = forwardRef<HTMLInputElement, TextInputProps>(
  ({ id, label, ...props }, ref) => (
    <div className="grid gap-1.5">
      <Label htmlFor={id}>{label}</Label>
      <Input id={id} ref={ref} {...props} />
    </div>
  )
)
TextInput.displayName = 'TextInput'
```

---

## React 19 APIs — reference only

**These are not the stack.** `react-standards` pins React 18 and is the single place the
version is stated. Do not write any of the right-hand column until that pin is changed;
this section exists so the migration is already written down when it is.

### Ref as a plain prop (replaces `forwardRef`)

```tsx
// React 18 — this stack
const TextInput = forwardRef<HTMLInputElement, TextInputProps>(
  ({ id, label, ...props }, ref) => (
    <div>
      <Label htmlFor={id}>{label}</Label>
      <Input id={id} ref={ref} {...props} />
    </div>
  )
)

// React 19 — only once react-standards pins React 19
function TextInput({ id, label, ref, ...props }: TextInputProps & { ref?: React.Ref<HTMLInputElement> }) {
  return (
    <div>
      <Label htmlFor={id}>{label}</Label>
      <Input id={id} ref={ref} {...props} />
    </div>
  )
}
```

### `use(Context)` (replaces `useContext()`)

```tsx
// React 18 — this stack
function ComposerInput() {
  const ctx = useContext(ComposerContext)
  // ...
}

// React 19 — only once react-standards pins React 19
function ComposerInput() {
  const ctx = use(ComposerContext)
  // ...
}

// Why React 19 wants it: use() is legal after an early return, useContext is not
function MaybeComposer({ show }: { show: boolean }) {
  if (!show) return null
  const ctx = use(ComposerContext)
  return <Textarea value={ctx.state.value} readOnly />
}
```

### Context provider syntax

```tsx
// React 18 — this stack
return <ComposerContext.Provider value={...}>{children}</ComposerContext.Provider>

// React 19 — only once react-standards pins React 19
return <ComposerContext value={...}>{children}</ComposerContext>
```
