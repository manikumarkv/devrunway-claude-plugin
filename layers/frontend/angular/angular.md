# Angular 17+ Standards

## App Bootstrap (Standalone)

```typescript
// src/main.ts
import { bootstrapApplication } from "@angular/platform-browser";
import { AppComponent } from "./app/app.component";
import { appConfig } from "./app/app.config";

bootstrapApplication(AppComponent, appConfig).catch(console.error);
```

```typescript
// src/app/app.config.ts
import { ApplicationConfig, provideZoneChangeDetection } from "@angular/core";
import { provideRouter, withComponentInputBinding } from "@angular/router";
import { provideHttpClient, withInterceptors } from "@angular/common/http";
import { routes } from "./app.routes";
import { authInterceptor } from "./core/interceptors/auth.interceptor";
import { errorInterceptor } from "./core/interceptors/error.interceptor";

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes, withComponentInputBinding()),
    provideHttpClient(withInterceptors([authInterceptor, errorInterceptor])),
  ],
};
```

## Standalone Component with Signals

```typescript
// src/app/features/dashboard/dashboard.component.ts
import {
  Component,
  signal,
  computed,
  inject,
  OnInit,
} from "@angular/core";
import { CommonModule } from "@angular/common";
import { toSignal } from "@angular/core/rxjs-interop";
import { UserService } from "../../core/services/user.service";

@Component({
  selector: "app-dashboard",
  standalone: true,
  imports: [CommonModule],
  template: `
    <div>
      <h1>Welcome, {{ userName() }}</h1>
      <p>Total orders: {{ orderCount() }}</p>
      <button (click)="increment()">Increment</button>
      @if (isLoading()) {
        <app-spinner />
      }
      @for (item of items(); track item.id) {
        <app-item-card [item]="item" />
      }
    </div>
  `,
})
export class DashboardComponent implements OnInit {
  private userService = inject(UserService);

  // Local signal state
  count = signal(0);
  isLoading = signal(false);

  // Convert Observable to signal
  user = toSignal(this.userService.currentUser$, { initialValue: null });

  // Computed derived value
  userName = computed(() => this.user()?.name ?? "Guest");
  orderCount = computed(() => this.user()?.orders.length ?? 0);

  items = signal<Item[]>([]);

  ngOnInit() {
    this.loadItems();
  }

  async loadItems() {
    this.isLoading.set(true);
    try {
      const data = await this.userService.getItems();
      this.items.set(data);
    } finally {
      this.isLoading.set(false);
    }
  }

  increment() {
    this.count.update((v) => v + 1);
  }
}
```

## HttpClient Service

```typescript
// src/app/core/services/order.service.ts
import { Injectable, inject } from "@angular/core";
import { HttpClient, HttpParams } from "@angular/common/http";
import { Observable, throwError } from "rxjs";
import { catchError, map } from "rxjs/operators";
import { environment } from "../../../environments/environment";

export interface Order {
  id: string;
  total: number;
  status: string;
}

@Injectable({ providedIn: "root" })
export class OrderService {
  private http = inject(HttpClient);
  private baseUrl = `${environment.apiUrl}/orders`;

  getOrders(page = 1, pageSize = 20): Observable<Order[]> {
    const params = new HttpParams()
      .set("page", page)
      .set("pageSize", pageSize);

    return this.http.get<{ data: Order[] }>(this.baseUrl, { params }).pipe(
      map((res) => res.data),
      catchError((err) => {
        console.error("Failed to fetch orders", err);
        return throwError(() => new Error("Could not load orders"));
      }),
    );
  }

  createOrder(payload: Partial<Order>): Observable<Order> {
    return this.http.post<Order>(this.baseUrl, payload).pipe(
      catchError((err) => throwError(() => err)),
    );
  }
}
```

## Functional Interceptors

```typescript
// src/app/core/interceptors/auth.interceptor.ts
import { HttpInterceptorFn } from "@angular/common/http";
import { inject } from "@angular/core";
import { AuthService } from "../services/auth.service";

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const token = auth.getToken();

  if (token) {
    const authReq = req.clone({
      setHeaders: { Authorization: `Bearer ${token}` },
    });
    return next(authReq);
  }
  return next(req);
};
```

```typescript
// src/app/core/interceptors/error.interceptor.ts
import { HttpInterceptorFn, HttpErrorResponse } from "@angular/common/http";
import { inject } from "@angular/core";
import { Router } from "@angular/router";
import { catchError, throwError } from "rxjs";

export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);

  return next(req).pipe(
    catchError((err: HttpErrorResponse) => {
      if (err.status === 401) {
        router.navigate(["/login"]);
      }
      return throwError(() => err);
    }),
  );
};
```

## Reactive Forms (Typed)

```typescript
// src/app/features/auth/login.component.ts
import { Component, inject } from "@angular/core";
import { FormBuilder, ReactiveFormsModule, Validators } from "@angular/forms";
import { CommonModule } from "@angular/common";

@Component({
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  template: `
    <form [formGroup]="form" (ngSubmit)="submit()">
      <input formControlName="email" type="email" placeholder="Email" />
      @if (email.invalid && email.touched) {
        <span class="error">
          {{ email.hasError("required") ? "Email is required" : "Enter a valid email" }}
        </span>
      }
      <input formControlName="password" type="password" placeholder="Password" />
      <button type="submit" [disabled]="form.invalid">Login</button>
    </form>
  `,
})
export class LoginComponent {
  private fb = inject(FormBuilder);

  form = this.fb.nonNullable.group({
    email: ["", [Validators.required, Validators.email]],
    password: ["", [Validators.required, Validators.minLength(8)]],
  });

  get email() { return this.form.controls.email; }
  get password() { return this.form.controls.password; }

  submit() {
    if (this.form.invalid) return;
    const { email, password } = this.form.getRawValue();
    // call auth service
  }
}
```

## Routing with Lazy Loading and Guards

```typescript
// src/app/app.routes.ts
import { Routes } from "@angular/router";
import { authGuard } from "./core/guards/auth.guard";

export const routes: Routes = [
  { path: "", redirectTo: "dashboard", pathMatch: "full" },
  {
    path: "auth",
    loadChildren: () => import("./features/auth/auth.routes").then((m) => m.AUTH_ROUTES),
  },
  {
    path: "dashboard",
    canActivate: [authGuard],
    loadComponent: () =>
      import("./features/dashboard/dashboard.component").then((m) => m.DashboardComponent),
  },
  {
    path: "orders",
    canActivate: [authGuard],
    loadChildren: () => import("./features/orders/orders.routes").then((m) => m.ORDER_ROUTES),
  },
];
```

```typescript
// src/app/core/guards/auth.guard.ts
import { CanActivateFn, Router } from "@angular/router";
import { inject } from "@angular/core";
import { AuthService } from "../services/auth.service";

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.isAuthenticated() || router.createUrlTree(["/auth/login"]);
};
```

## Subscription Management

```typescript
// Use takeUntilDestroyed — no manual ngOnDestroy needed
import { takeUntilDestroyed } from "@angular/core/rxjs-interop";
import { DestroyRef, inject } from "@angular/core";

export class MyComponent {
  private destroyRef = inject(DestroyRef);

  ngOnInit() {
    this.someService.data$
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe((data) => this.data.set(data));
  }
}

// Or in constructor (no destroyRef needed)
export class MyComponent {
  data = toSignal(inject(SomeService).data$, { initialValue: [] });
}
```

## Checklist

- [ ] All new components are `standalone: true`
- [ ] `toSignal()` used to convert Observables for template consumption
- [ ] `inject()` used for dependency injection — no constructor parameter injection
- [ ] Functional guards replace class-based guards
- [ ] Feature routes use `loadComponent` / `loadChildren` for lazy loading
- [ ] Typed FormGroup with `nonNullable` group
- [ ] Subscriptions managed with `takeUntilDestroyed` — no `ngOnDestroy` for cleanup
- [ ] Functional interceptors added via `withInterceptors([...])`
