# Accessibility Standards (WCAG 2.1 AA)

---

## Semantic HTML first — CRITICAL

Use the right HTML element before reaching for ARIA. A `<button>` is keyboard-focusable, activatable, and announced correctly by screen readers — a `<div>` is none of these.

```tsx
// ❌ — requires manual ARIA + JS to work accessibly
<div onClick={handleSubmit} className="btn">Submit</div>

// ✅ — works out of the box: keyboard, screen reader, focus
<button type="button" onClick={handleSubmit}>Submit</button>
```

```tsx
// ❌ — generic containers
<div className="nav">...</div>
<div className="main-content">...</div>
<div className="page-header">...</div>

// ✅ — landmark elements (screen reader navigation)
<nav aria-label="Main navigation">...</nav>
<main>...</main>
<header>...</header>
<footer>...</footer>
<aside aria-label="Related links">...</aside>
```

```tsx
// ❌ — link used as a button (no href = not a link)
<a onClick={openModal}>Open settings</a>

// ✅ — button for actions, anchor for navigation
<button type="button" onClick={openModal}>Open settings</button>
<a href="/settings">Go to settings</a>
```

---

## Interactive elements

### Every interactive element must be keyboard reachable and operable

```tsx
// ❌ — keyboard users can't interact
<div onClick={toggle} className="accordion-header">Section</div>

// ✅ — keyboard: Enter/Space activate, Tab reaches it
<button
  type="button"
  onClick={toggle}
  aria-expanded={isOpen}
  aria-controls="accordion-panel"
>
  Section
</button>
<div id="accordion-panel" hidden={!isOpen}>...</div>
```

### Never remove focus outlines without a replacement

```css
/* ❌ — invisible focus, keyboard users lost */
*:focus { outline: none; }
button:focus { outline: 0; }

/* ✅ — custom focus ring that's visible */
button:focus-visible {
  outline: 2px solid #2563eb;
  outline-offset: 2px;
  border-radius: 4px;
}
```

Use `:focus-visible` (not `:focus`) so mouse users don't see the ring but keyboard users do.

### Avoid positive tabIndex — it breaks natural tab order

```tsx
// ❌ — forces unnatural tab order
<button tabIndex={2}>Second</button>
<button tabIndex={1}>First</button>

// ✅ — let the DOM order determine tab order
<button>First</button>
<button>Second</button>

// tabIndex={0}: makes non-interactive element focusable (rarely needed)
// tabIndex={-1}: removes from tab order but still focusable via JS (modals, etc.)
```

---

## Forms — HIGH IMPACT

### Every input needs a visible label

```tsx
// ❌ — no label: screen readers can't identify the field
<input type="email" placeholder="Enter your email" />

// ❌ — placeholder disappears on type, not a label
<input type="email" placeholder="Email address" />

// ✅ — explicit label association
<label htmlFor="email">Email address</label>
<input id="email" type="email" />

// ✅ — or wrap input in label
<label>
  Email address
  <input type="email" />
</label>

// ✅ — visually hidden label (when design requires no visible label)
<label htmlFor="search" className="sr-only">Search</label>
<input id="search" type="search" />
```

### Link error messages to their input

```tsx
// ❌ — error visible but not associated with the field
<input id="email" type="email" />
<p className="error">Invalid email address</p>

// ✅ — aria-describedby links error to input
<input
  id="email"
  type="email"
  aria-invalid={!!error}
  aria-describedby={error ? 'email-error' : undefined}
/>
{error && (
  <p id="email-error" role="alert">{error}</p>
)}
```

### Required fields — both visually and programmatically

```tsx
// ✅
<label htmlFor="name">
  Full name <span aria-hidden="true">*</span>
</label>
<input id="name" type="text" required aria-required="true" />
<p id="form-note">Fields marked with * are required</p>
```

---

## Images and icons

```tsx
// ❌ — missing alt
<img src="/hero.png" />

// ✅ — meaningful alt text (describes content, not "image of...")
<img src="/hero.png" alt="Team collaborating around a whiteboard" />

// ✅ — decorative image: empty alt hides from screen readers
<img src="/decorative-divider.png" alt="" />

// ✅ — icon button: label the button, hide the icon
<button type="button" aria-label="Close dialog">
  <XIcon aria-hidden="true" />
</button>

// ✅ — icon with visible text: hide icon from screen reader
<button type="button">
  <SearchIcon aria-hidden="true" />
  Search
</button>
```

---

## Dynamic content — aria-live

Content that updates without a page load must be announced to screen readers.

```tsx
// ❌ — status updates silently
const [status, setStatus] = useState('')
return <p>{status}</p>

// ✅ — aria-live announces changes
return (
  <p aria-live="polite" aria-atomic="true">
    {status}
  </p>
)

// aria-live="polite"   — announces when user is idle (most updates)
// aria-live="assertive" — interrupts immediately (errors, critical alerts)
// aria-atomic="true"   — reads the whole region, not just changed part
```

```tsx
// ✅ — toast notifications
function Toast({ message }: { message: string }) {
  return (
    <div role="status" aria-live="polite">
      {message}
    </div>
  )
}

// ✅ — form validation errors
function FormError({ error }: { error: string }) {
  return (
    <p role="alert" aria-live="assertive">
      {error}
    </p>
  )
}
```

---

## Modals and dialogs

```tsx
// ✅ — correct modal implementation
function Modal({ isOpen, onClose, title, children }: ModalProps) {
  const dialogRef = useRef<HTMLDialogElement>(null)
  const previousFocus = useRef<HTMLElement | null>(null)

  useEffect(() => {
    if (isOpen) {
      previousFocus.current = document.activeElement as HTMLElement
      dialogRef.current?.focus()  // move focus into dialog
    } else {
      previousFocus.current?.focus()  // restore focus on close
    }
  }, [isOpen])

  if (!isOpen) return null

  return (
    // role="dialog", aria-modal, aria-labelledby are all required
    <div
      ref={dialogRef}
      role="dialog"
      aria-modal="true"
      aria-labelledby="dialog-title"
      tabIndex={-1}  // makes div focusable for initial focus
    >
      <h2 id="dialog-title">{title}</h2>
      {children}
      <button type="button" onClick={onClose} aria-label="Close dialog">
        <XIcon aria-hidden="true" />
      </button>
    </div>
  )
}
```

Focus trap: Tab should cycle within the modal, not escape to the page behind it. Use a library like `focus-trap-react` rather than implementing manually.

```tsx
import FocusTrap from 'focus-trap-react'

function Modal({ isOpen, onClose, children }: ModalProps) {
  if (!isOpen) return null
  return (
    <FocusTrap>
      <div role="dialog" aria-modal="true">
        {children}
        <button onClick={onClose}>Close</button>
      </div>
    </FocusTrap>
  )
}
```

---

## Navigation and headings

```tsx
// ✅ — one h1 per page, logical heading hierarchy
<h1>Dashboard</h1>          {/* page title */}
  <h2>Recent Activity</h2>  {/* section */}
    <h3>Today</h3>          {/* sub-section */}
  <h2>Team Members</h2>

// ❌ — skip heading levels
<h1>Dashboard</h1>
<h3>Recent Activity</h3>    {/* jumped from h1 to h3 */}
```

```tsx
// ✅ — skip link (first element in <body>, appears on focus)
function SkipLink() {
  return (
    <a
      href="#main-content"
      className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4"
    >
      Skip to main content
    </a>
  )
}

function App() {
  return (
    <>
      <SkipLink />
      <nav>...</nav>
      <main id="main-content">...</main>
    </>
  )
}
```

---

## Color and contrast

- **Text**: minimum 4.5:1 contrast ratio against background (AA)
- **Large text** (18px+ or 14px+ bold): minimum 3:1
- **UI components / focus indicators**: minimum 3:1
- **Never use color alone** to convey meaning — always pair with text, icon, or pattern

```tsx
// ❌ — color-only status (invisible to colorblind users)
<span style={{ color: isError ? 'red' : 'green' }}>
  {isError ? 'Failed' : 'Success'}
</span>

// ✅ — color + icon + text
<span className={isError ? 'text-red-600' : 'text-green-600'}>
  {isError ? <ErrorIcon aria-hidden="true" /> : <CheckIcon aria-hidden="true" />}
  {isError ? 'Failed' : 'Success'}
</span>
```

---

## Visually hidden utility class

Use for content that screen readers need but shouldn't be visible:

```css
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}
```

(Built into Tailwind as `className="sr-only"`)

```tsx
// ✅ — icon button with screen reader label
<button type="button">
  <HeartIcon aria-hidden="true" />
  <span className="sr-only">Add to favourites</span>
</button>
```
