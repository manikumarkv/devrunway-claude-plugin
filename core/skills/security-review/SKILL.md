---
name: security-review
description: Security audit of the current branch — OWASP Top 10, secrets scanning, Cognito auth patterns, IAM least-privilege. Outputs SECURITY-REVIEW-<branch>.md with PASS/FAIL per check and an overall verdict. Usage — /security-review [branch-name]
argument-hint: "[branch-name]"
arguments:
  - name: branch
    description: "Branch to audit (default: current branch)"
user-invocable: true
context: fork
effort: medium
agent: security-reviewer
allowed-tools:
  - Read
  - Grep
  - Bash(git *)
  - Bash(npm audit)
  - Bash(grep *)
---

# Security Review

Delegates to the **security-reviewer** agent for a full OWASP-based audit of the current branch.

Parse `$ARGUMENTS[0]` as an optional branch name (default: current branch).

---

The security-reviewer agent will:
1. Identify all files changed vs `develop` (or `main`)
2. Run `npm audit --audit-level=high` — CVE scan
3. Scan for hardcoded secrets with grep patterns
4. Apply OWASP Top 10 checks per file type (auth, controllers, React, CDK)
5. Verify Cognito patterns: `requireAuth`, `requireGroup('Admin')`, no hardcoded pool IDs
6. Check logging for PII leakage
7. Write `SECURITY-REVIEW-<branch>.md` with PASS/FAIL per check and overall verdict

Run this alongside `/dev-review` before every `/pr create`.

**Related skills — apply together:**
- `dev-review` — full code quality review (run both before PR)
- `security-standards` — security rules applied during implementation
- `logging-standards` — PII rules referenced during log checks
- `cdk` — IAM least-privilege rules for infrastructure files
