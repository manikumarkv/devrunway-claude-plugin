---
name: standards
description: Coding standards and conventions for this project stack (React, Node.js, AWS, Cognito, GitHub). Load when writing, reviewing, or discussing any code in this project.
user-invocable: false
---

For detailed standards, see [standards.md](standards.md). Key rules to always apply:

**Git:** Branch names: `feature/<GH-id>-<desc>` or `fix/<GH-id>-<desc>`. Commits follow Conventional Commits: `feat|fix|chore|refactor|test|docs(scope): summary`. PRs target `develop`, not `main`.

**React:** Functional components only. Props typed with `interface`. Server state via React Query — no manual fetch in `useEffect`. Business logic in custom hooks, not components. Co-locate tests as `Component.test.tsx`.

**Node.js:** Controllers are thin (call service, return response). Validation via `zod` at controller boundary. All async handlers wrapped with `asyncHandler`. Centralized error middleware. Structured JSON logging with `pino` — no `console.log` in production.

**AWS:** Resources named `<project>-<env>-<service>-<type>`. All infra via CDK in `infra/`. IAM least-privilege — no `*` resources in prod. Secrets in SSM/Secrets Manager — never in `.env` committed to git.

**Cognito:** Verify JWTs server-side with `aws-jwt-verify`. Authorization by Cognito group (`Admin`, `User`), never by username/email. Never store tokens in `localStorage` — use memory or `HttpOnly` cookies.

**Quality gates:** TypeScript strict mode. ESLint zero errors. Tests pass. No `console.log`, no hardcoded secrets, no untracked `TODO`/`FIXME`.
