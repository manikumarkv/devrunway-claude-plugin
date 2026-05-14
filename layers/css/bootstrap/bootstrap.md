# Bootstrap 5 Standards

---

## Setup

```bash
npm install bootstrap @popperjs/core
# For SCSS customisation:
npm install --save-dev sass
```

```scss
// src/styles/custom.scss — single entry point
// Step 1: Override variables BEFORE importing Bootstrap
$primary:          #0d6efd;
$secondary:        #6c757d;
$success:          #198754;
$font-family-base: 'Inter', system-ui, sans-serif;
$border-radius:    0.5rem;
$border-radius-lg: 0.75rem;
$spacer:           1rem;

// Step 2: Import Bootstrap
@import "bootstrap/scss/bootstrap";

// Step 3: Project-specific utilities and overrides
.btn-brand {
  @include button-variant(#ff6b00, #ff6b00);
}
```

```typescript
// Import JS components individually — not the full bundle
import { Modal, Dropdown, Toast } from 'bootstrap'
```

---

## SCSS variable overrides

```scss
// Typography
$font-family-base:     'Inter', system-ui, -apple-system, sans-serif;
$font-size-base:       1rem;       // 16px
$line-height-base:     1.5;
$headings-font-weight: 600;

// Colours
$primary:   #0d6efd;
$danger:    #dc3545;
$success:   #198754;
$warning:   #ffc107;
$info:      #0dcaf0;
$light:     #f8f9fa;
$dark:      #212529;

// Spacing
$spacer: 1rem;   // base for mt-1 = 0.25rem, mt-3 = 1rem, mt-5 = 3rem

// Border
$border-radius:    0.375rem;
$border-radius-lg: 0.5rem;
$border-radius-sm: 0.25rem;

// Shadows
$box-shadow:    0 0.5rem 1rem rgba(0, 0, 0, 0.15);
$box-shadow-sm: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
```

---

## Grid and layout

```html
<!-- Mobile-first: define xs, override at breakpoints -->
<div class="container">
  <div class="row g-3">
    <div class="col-12 col-md-6 col-lg-4">Card A</div>
    <div class="col-12 col-md-6 col-lg-4">Card B</div>
    <div class="col-12 col-md-12 col-lg-4">Card C</div>
  </div>
</div>

<!-- Flexbox utilities -->
<div class="d-flex align-items-center gap-2">
  <img src="avatar.png" class="rounded-circle" width="40" height="40" alt="User avatar">
  <span>John Doe</span>
</div>

<!-- CSS Grid (Bootstrap 5.1+) -->
<div class="grid" style="--bs-columns: 3; --bs-gap: 1rem;">
  <div class="g-col-1">Item</div>
  <div class="g-col-2">Wide item</div>
</div>
```

---

## Utility classes — reference

```html
<!-- Spacing (m = margin, p = padding; t/b/s/e/x/y = top/bottom/start/end/x-axis/y-axis) -->
<div class="mt-3 mb-2 px-4 py-2">  <!-- mt=1rem, mb=0.5rem, px=1.5rem, py=0.5rem -->

<!-- Display -->
<div class="d-none d-md-block">   <!-- hidden on xs, visible md+ -->
<div class="d-flex d-lg-grid">

<!-- Text -->
<p class="text-truncate" style="max-width: 200px;">Long text...</p>
<span class="text-muted fw-semibold fs-6">Label</span>

<!-- Borders and shadows -->
<div class="border border-primary rounded-3 shadow-sm p-3">

<!-- Position -->
<div class="position-relative">
  <span class="position-absolute top-0 end-0 badge bg-danger">3</span>
</div>
```

---

## Components

### Buttons

```html
<!-- Variants -->
<button class="btn btn-primary">Primary</button>
<button class="btn btn-outline-secondary">Secondary</button>
<button class="btn btn-sm btn-danger">Delete</button>

<!-- Loading state (manual) -->
<button class="btn btn-primary" disabled>
  <span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>
  Saving...
</button>

<!-- Icon-only — always add aria-label -->
<button class="btn btn-outline-secondary" aria-label="Close">
  <i class="bi bi-x-lg"></i>
</button>
```

### Modal

```html
<!-- Trigger via data attributes — no JS needed -->
<button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#confirmModal">
  Delete
</button>

<div class="modal fade" id="confirmModal" tabindex="-1" aria-labelledby="confirmModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title" id="confirmModalLabel">Confirm deletion</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <div class="modal-body">
        Are you sure? This action cannot be undone.
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
        <button type="button" class="btn btn-danger" id="confirmDeleteBtn">Delete</button>
      </div>
    </div>
  </div>
</div>
```

```typescript
// Programmatic control when you need it
import { Modal } from 'bootstrap'

const el = document.getElementById('confirmModal')!
const modal = Modal.getOrCreateInstance(el)

modal.show()
modal.hide()

// Listen to events
el.addEventListener('hidden.bs.modal', () => {
  // cleanup
})
```

### Forms

```html
<!-- Always pair label + control with for/id -->
<div class="mb-3">
  <label for="email" class="form-label">Email address</label>
  <input
    type="email"
    class="form-control"
    id="email"
    name="email"
    placeholder="you@example.com"
    required
    aria-describedby="emailHelp"
  >
  <div id="emailHelp" class="form-text">We'll never share your email.</div>
</div>

<!-- Validation states -->
<input class="form-control is-invalid" ...>
<div class="invalid-feedback">Please enter a valid email address.</div>

<input class="form-control is-valid" ...>
<div class="valid-feedback">Looks good!</div>

<!-- Floating labels -->
<div class="form-floating mb-3">
  <input type="email" class="form-control" id="floatEmail" placeholder="name@example.com">
  <label for="floatEmail">Email address</label>
</div>
```

### Alerts and toasts

```html
<!-- Alert — dismissible -->
<div class="alert alert-danger alert-dismissible fade show" role="alert">
  <strong>Error:</strong> Something went wrong.
  <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
</div>

<!-- Toast -->
<div class="toast-container position-fixed bottom-0 end-0 p-3">
  <div id="successToast" class="toast" role="alert" aria-live="assertive" aria-atomic="true">
    <div class="toast-header">
      <strong class="me-auto">Success</strong>
      <button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="Close"></button>
    </div>
    <div class="toast-body">Order saved successfully.</div>
  </div>
</div>
```

```typescript
import { Toast } from 'bootstrap'

function showToast(id: string) {
  const el = document.getElementById(id)!
  Toast.getOrCreateInstance(el).show()
}
```

---

## Extending utilities with the utilities API

```scss
// Add custom utilities without writing ad-hoc CSS classes
$utilities: map-merge(
  $utilities,
  (
    "cursor": (
      property: cursor,
      values: auto default pointer grab,
    ),
    "min-width": (
      property: min-width,
      class: min-w,
      values: (
        0: 0,
        25: 25%,
        50: 50%,
        75: 75%,
        100: 100%,
      ),
    ),
  )
);
```

Usage: `<div class="cursor-pointer min-w-50">`

---

## Dark mode (Bootstrap 5.3+)

```html
<!-- Set data-bs-theme on html element -->
<html lang="en" data-bs-theme="dark">

<!-- Or per-component -->
<div class="card" data-bs-theme="dark">...</div>
```

```typescript
// Toggle
function toggleTheme() {
  const html = document.documentElement
  const current = html.getAttribute('data-bs-theme')
  html.setAttribute('data-bs-theme', current === 'dark' ? 'light' : 'dark')
  localStorage.setItem('theme', html.getAttribute('data-bs-theme')!)
}

// Restore on load
const saved = localStorage.getItem('theme') ?? 'light'
document.documentElement.setAttribute('data-bs-theme', saved)
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Editing `node_modules/bootstrap/` | Override via SCSS variables in `custom.scss` |
| `import 'bootstrap/dist/js/bootstrap.bundle.min.js'` in a bundled app | Import individual components: `import { Modal } from 'bootstrap'` |
| `margin-right` on flex children for spacing | `gap-2` on the flex container |
| Icon-only button with no label | Add `aria-label="Close"` — Bootstrap btn-close has it; custom icons don't |
| `d-none` for screen-reader text | Use `.visually-hidden` — `d-none` hides from screen readers too |
| Importing compiled CSS instead of SCSS | Import `bootstrap/scss/bootstrap` to enable variable overrides |
| Overriding compiled `.btn-primary` colour directly | Override `$primary` before the Bootstrap import |
