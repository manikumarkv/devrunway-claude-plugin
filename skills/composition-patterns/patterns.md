# React Composition Patterns

Source: Vercel Engineering agent-skills — composition-patterns

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
interface ComposerContextValue {
  value: string
  onChange: (value: string) => void
  onSubmit: () => void
  isSubmitting: boolean
  error: string | null
}

const ComposerContext = createContext<ComposerContextValue | null>(null)

function useComposer() {
  const ctx = use(ComposerContext)  // React 19
  if (!ctx) throw new Error('Must be used within Composer')
  return ctx
}

function ComposerInput() {
  const { value, onChange, error } = useComposer()
  return (
    <>
      <textarea value={value} onChange={e => onChange(e.target.value)} />
      {error && <span>{error}</span>}
    </>
  )
}

function ComposerFooter() {
  const { onSubmit, isSubmitting } = useComposer()
  return <button onClick={onSubmit} disabled={isSubmitting}>Send</button>
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
    <ComposerContext value={{ value, onChange: setValue, onSubmit, isSubmitting, error }}>
      {children}
    </ComposerContext>
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
    <textarea
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
  return <ComposerContext value={...}>{children}</ComposerContext>
}

// Provider B: globally synced state (e.g. editing a draft)
function DraftProvider({ draftId, children }: { draftId: string; children: React.ReactNode }) {
  const draft = useDraft(draftId)  // synced to server
  const submit = async () => publishDraft(draftId)
  // ...same interface, different implementation
  return <ComposerContext value={...}>{children}</ComposerContext>
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
  renderInput={(value, onChange) => <textarea value={value} onChange={e => onChange(e.target.value)} />}
  renderFooter={(onSubmit) => <button onClick={onSubmit}>Send</button>}
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

## React 19 APIs

### No `forwardRef` — accept `ref` as a regular prop

```tsx
// ❌ React 18 — forwardRef wrapper
const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, ...props }, ref) => (
    <label>
      {label}
      <input ref={ref} {...props} />
    </label>
  )
)

// ✅ React 19 — ref is just a prop
function Input({ label, ref, ...props }: InputProps & { ref?: React.Ref<HTMLInputElement> }) {
  return (
    <label>
      {label}
      <input ref={ref} {...props} />
    </label>
  )
}
```

### `use(Context)` instead of `useContext()`

```tsx
// ❌ React 18
function ComposerInput() {
  const ctx = useContext(ComposerContext)
  // ...
}

// ✅ React 19 — use() works inside conditionals and loops too
function ComposerInput() {
  const ctx = use(ComposerContext)
  // ...
}

// Bonus: use() works conditionally (useContext does not)
function MaybeComposer({ show }: { show: boolean }) {
  if (!show) return null
  const ctx = use(ComposerContext)  // valid — after early return
  return <textarea value={ctx.state.value} />
}
```

### Context provider syntax — no `.Provider` needed

```tsx
// ❌ React 18
return <ComposerContext.Provider value={...}>{children}</ComposerContext.Provider>

// ✅ React 19
return <ComposerContext value={...}>{children}</ComposerContext>
```
