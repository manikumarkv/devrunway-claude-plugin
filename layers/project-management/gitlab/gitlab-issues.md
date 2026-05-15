# GitLab Issues — Full Standards

## Issue templates

Every project has issue templates under `.gitlab/issue_templates/`. Required templates:

- `Bug.md` — what happened, steps to reproduce, expected vs actual, environment, logs
- `Feature.md` — user story, acceptance criteria, out-of-scope, dependencies
- `Tech-Debt.md` — what code, why it's debt, impact, proposed fix

Example minimal `Bug.md`:

```markdown
## Summary

## Steps to reproduce
1.
2.

## Expected behaviour

## Actual behaviour

## Environment
- Browser/OS:
- Version:

## Logs / screenshots
```

## Labels and label policy

Maintain `.gitlab/labels.yml` and sync via CI:

```yaml
- name: priority::critical
  color: "#FF0000"
- name: priority::high
  color: "#FF8800"
- name: status::in-progress
  color: "#33CCFF"
- name: type::bug
  color: "#CC0033"
- name: security
  color: "#000000"
```

Scoped labels (`category::value`) are mutually exclusive — applying `priority::high` removes any other `priority::*`.

## Weights (story points)

Use Fibonacci: 1, 2, 3, 5, 8. Issues over 8 must be split.

## Milestones and iterations

- Milestone = release or fixed-date goal
- Iteration = recurring sprint (e.g. two-week cycle)
- An issue can belong to one milestone AND one iteration

## Boards

Default columns: `Open → status::ready → status::in-progress → status::in-review → Closed`

Filter the board by milestone or iteration to scope to current work.

## MR linking

In MR description:

```markdown
Closes #123, #124
Refs #200
```

`Closes` auto-closes the issue on merge; `Refs` links without closing.

## MCP tool usage

Prefer:
- `mcp__gitlab__create_issue`
- `mcp__gitlab__list_issues`
- `mcp__gitlab__update_issue`
- `mcp__gitlab__create_merge_request`

Over CLI: `glab issue create`, `glab issue list`, etc.

## Never

- Plain text issues without a template
- Free labels where a scoped label exists
- Skipping milestone assignment before In Progress
- Two assignees on one issue
