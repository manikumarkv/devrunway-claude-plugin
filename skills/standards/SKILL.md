---
name: standards
description: Universal software engineering principles — naming, single responsibility, DRY, test proximity, explicit dependencies, fail fast. Applies to any language or stack. Load always.
user-invocable: false
paths:
  - "**/*"
---

Full standards in [standards.md](standards.md). Always-on principles:

**Naming:** Names are documentation. A function named `process()` documents nothing; `validatePaymentAmount()` documents intent, input, and scope. Choose the longer, clearer name.

**Single responsibility:** A function does one thing. A module owns one concept. If you need "and" to describe what something does, split it.

**DRY:** Extract when you see the same logic in 3 or more places. Duplication under 3 is usually fine — premature abstraction creates worse problems than duplication.

**Tests alongside source:** Test files live next to the code they test, not in a separate `tests/` tree. Tests are documentation of expected behaviour.

**Explicit dependencies:** A function declares everything it needs as parameters. No hidden globals, no reaching into singletons from inside business logic. Infrastructure (DB, logger, config) is injected, not imported directly into services.

**Fail fast at the boundary:** Validate inputs at the entry point. Once inside the system, trust the types. Never proceed with invalid data — fail loudly immediately.

**No dead code:** Remove commented-out code, unused imports, and unreachable branches. Version control is the history; the codebase is the present.

**For tech-specific implementation standards, consult your installed layer skills.**
