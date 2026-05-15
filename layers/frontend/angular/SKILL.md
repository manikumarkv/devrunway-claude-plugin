---
name: angular
description: Angular 17+ — standalone components, signals, inject(), HttpClient, reactive forms, guards, lazy loading
user-invocable: false
stack: frontend/angular
paths:
  - "**/*.component.ts"
  - "**/*.component.html"
  - "**/*.service.ts"
  - "**/*.guard.ts"
  - "**/*.resolver.ts"
  - "**/angular.json"
  - "**/*.module.ts"
---

Full standards in [angular.md](angular.md). Always-on summary:

**Standalone Components:**
- Use standalone components (`standalone: true`) for all new components — avoid the legacy module system
- Declare only what the component needs directly: `imports: [CommonModule, ReactiveFormsModule]`
- Bootstrap with `bootstrapApplication(AppComponent, appConfig)` — not `platformBrowserDynamic`

**Signals:**
- Use `signal()` for local mutable state, `computed()` for derived values, `effect()` for side effects
- Prefer signals over RxJS streams (e.g. reactive value holders) for component state — cleaner, no subscription management
- Use `toSignal()` to convert Observables to signals in templates

**Dependency Injection:**
- Use `inject()` function in constructors and factory functions — preferred over constructor injection for new code
- Mark services as `providedIn: 'root'` unless scoped to a feature module
- Use `InjectionToken<T>` for values that cannot be a class

**HttpClient:**
- Always handle errors with `catchError` — never let Observable errors propagate unhandled
- Use `HttpInterceptorFn` (functional interceptors, Angular 15+) for auth, logging, and error handling
- Provide interceptors via `withInterceptors([...])` in `provideHttpClient()`

**Reactive Forms:**
- Use `FormBuilder` with typed `FormGroup<T>` — enables strong typing on `.value`
- Validate with built-in validators and custom `ValidatorFn` — never inline validation in templates
- Show errors only when the control is `touched` or the form has been submitted

**Guards and Routing:**
- Use functional guards (`CanActivateFn`) — not class-based guards
- Lazy-load feature routes: `loadComponent` for single components, `loadChildren` for route groups
- Use `resolve` to prefetch data before navigation — prevents flash of empty content

**Never:**
- Use `any` type — use `unknown` and type guards
- Subscribe in a component without using `takeUntilDestroyed()` or `AsyncPipe`
- Use `ngOnDestroy` just to unsubscribe — use `DestroyRef` or `takeUntilDestroyed()`
- Mutate signal values from outside the owning component

**Related skills:** `accessibility`, `linting`, `api-conventions`
