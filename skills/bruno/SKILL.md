---
name: bruno
description: Bruno API testing standards — collection structure, environment variables, auth setup, test scripts, CI integration. Load when writing or reviewing Bruno API tests.
user-invocable: false
---

Full standards in [bruno.md](bruno.md). Always-on summary:

**Collection structure:**
```
bruno/
  environments/
    local.bru
    staging.bru
  <feature>/
    create-<resource>.bru
    get-<resource>.bru
    update-<resource>.bru
    delete-<resource>.bru
```

**Every request must have:**
- Auth header using `{{token}}` env variable
- `tests {}` block asserting status code and response shape
- Descriptive name matching the operation

**Auth:** use `pre-request` script to fetch Cognito token once, store in env.

**CI:** `npx @usebruno/cli run bruno/ --env staging` in GitHub Actions post-deploy.

**Never:**
- Hard-code tokens or IDs in request files
- Commit `environments/local.bru` with real credentials
- Skip the `tests {}` block — every request must assert something


**Related skills — apply together:**
- `api-conventions` — Bruno requests follow the same envelope, versioning, and status code rules
- `error-handling` — test 4xx and 5xx responses, not just happy paths
- `pipeline` — Bruno collection runs in CI after staging deploy as a required check