---
name: debug
description: Debug a bug or check production logs by delegating to the debugger agent. 'this' investigates a reported bug. 'logs' runs a CloudWatch health check. Usage — /devrunway:debug [this|logs] [description]
argument-hint: "[this|logs] [error description or env]"
arguments:
  - name: subcommand
    description: "this (default) — investigate and fix a bug. logs — CloudWatch health check."
  - name: args
    description: "Error description, stack trace snippet, or environment name (staging|prod)"
user-invocable: true
allowed-tools:
  - Read
  - Grep
  - Bash(git *)
  - Bash(aws logs *)
  - Bash(aws cloudwatch *)
  - Bash(aws sts *)
  - Bash(jq *)
  - Bash(date *)
context: fork
agent: debugger
---

# Debugger

Delegate to the **debugger** agent for systematic root-cause investigation or production log monitoring.

Sub-command is `$ARGUMENTS[0]`. Defaults to `this` if omitted.

---

## `/debug this [error description]`

Investigate a bug. Delegates to the debugger agent in Mode 1 (Bug Investigation).

Pass any available context from `$ARGUMENTS` (error message, stack trace, HTTP status, affected route) to the debugger agent so it can begin forming hypotheses immediately.

The debugger agent will:
1. Ask clarifying questions if needed: when did it start, all users or specific, which environment
2. Check `git log --oneline -20` for recent changes
3. Form ranked hypotheses
4. Trace the code path: controller → service → repository → middleware
5. State the root cause with evidence (file:line)
6. Write a failing test that proves the bug
7. Apply the minimal fix
8. Verify all tests pass, TypeScript clean, lint clean
9. Produce a Bug Fix Report

After the debugger agent completes, suggest: "Run `/pr create` to open a PR with the fix."

---

## `/debug logs [env]`

Check production/staging health via CloudWatch. Delegates to the debugger agent in Mode 2 (Log Monitoring).

Pass `$ARGUMENTS[1]` as the environment (default: `staging`).

The debugger agent will:
1. Verify AWS credentials
2. Pull errors from CloudWatch (last 1 hour)
3. Pull p95/p99 latency metrics
4. Analyse and rate health (🟢 / 🟡 / 🔴)
5. Print the Log Health Check report

If unhealthy, the agent will suggest specific next actions based on the error patterns found.

After the health check, suggest: "Run `/logs tail <env>` to stream live logs."
