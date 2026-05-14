---
name: postman
description: Postman API testing conventions — collection structure, environment variables, pre-request scripts, test assertions, and Newman CI runner. Load when working with Postman collections.
user-invocable: false
stack: testing/api/postman
paths:
  - "postman/**"
  - "**/*.postman_collection.json"
  - "**/*.postman_environment.json"
---

Full standards in [postman.md](postman.md). Always-on summary:

**Collection structure:**
- One collection per API domain (e.g. `Orders API`, `Auth API`)
- Folders mirror API routes: `Orders > Create Order`, `Orders > Get Order`
- Each request has a name that reads as a sentence: `Create order with valid items`

**Environments:**
- `Local`, `Staging`, `Production` environments — never hardcode URLs or tokens
- All base URLs, tokens, and IDs in environment variables: `{{base_url}}`, `{{auth_token}}`
- Never commit production credentials — use environment files with placeholders

**Test scripts (Tests tab):**
- Every request has at least one test — status code assertion minimum
- Use `pm.test()` with descriptive names
- Chain requests: extract IDs from responses into variables for subsequent requests

**Pre-request scripts:**
- Generate dynamic data (timestamps, UUIDs) in pre-request scripts
- Fetch auth tokens programmatically — don't manually paste them

**CI with Newman:**
- `newman run collection.json -e environment.json --reporters cli,junit`
- Export collections from Postman; commit them to version control

**Never:**
- Hardcode auth tokens or IDs in request bodies
- Use `{{$randomEmail}}` in tests that assert on the value (it changes every run)
- Leave "No tests" on requests that hit the server

**Related skills:** `api-conventions` (response envelope structure to assert against)
