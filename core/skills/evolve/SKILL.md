---
name: evolve
description: Analyse the plugin's own skills and agents against real project experience and recommend targeted improvements. Usage — /evolve
argument-hint: "[focus area: skills|agents|coverage|all]"
arguments:
  - name: focus
    description: "skills, agents, coverage, or all (default: all)"
user-invocable: true
context: fork
effort: high
allowed-tools:
  - Read
  - Write
  - Bash(find *)
  - Bash(ls *)
  - Bash(git *)
  - Bash(grep *)
---

# Evolve

Analyse the plugin's current state against real project usage and produce a
prioritised improvement plan. This closes the SDLC feedback loop — each sprint
makes the plugin smarter for the next one.

Parse `$ARGUMENTS[0]` as focus area (`skills` | `agents` | `coverage` | `all`, default `all`).

---

## Step 1 — Collect evidence

Run all of these before forming any opinion:

```bash
# 1. Recent review reports — what issues keep recurring?
find . -name 'REVIEW-*.md' | sort -r | head -10

# 2. Recent debug reports — what root causes keep appearing?
find . -name 'DEBUG-*.md' -o -name 'BUG-REPORT-*.md' | sort -r | head -10

# 3. Recent design docs — what patterns are being used?
find docs/design/ -name '*.md' 2>/dev/null | sort -r | head -10

# 4. Skills that still have TODO placeholders (not yet fully defined)
grep -rl 'TODO' skills/ --include='*.md' | head -20

# 5. Skills with no related-skills cross-references yet
grep -rL 'Related skills' skills/*/SKILL.md | head -20

# 6. Commands used most in recent git log
git log --oneline -50 | grep -oE '/(scaffold|design|review|debug|deploy|branch|pr|test|fix|task|logs)' | sort | uniq -c | sort -rn

# 7. Recent commits — what areas are changing most?
git log --oneline -30 --name-only | grep 'src/' | grep -oE 'src/[^/]+/' | sort | uniq -c | sort -rn
```

Read all REVIEW-*.md files found. Extract:
- Recurring issue categories (security, types, testing, performance)
- Rules Claude missed or applied inconsistently
- Patterns not covered by any current skill

Read all DEBUG-*.md files found. Extract:
- Root cause categories
- Which skills, if stronger, would have prevented the bug

---

## Step 2 — Audit skill coverage against SDLC stages

Check every stage has full skill coverage:

| SDLC Stage | Skills that cover it | Gap? |
|---|---|---|
| Requirements | product-persona | — |
| Tech design | api-conventions, project-structure, database-sql, database-nosql | — |
| Implementation | react-standards, typescript-patterns, error-handling, security, packages | — |
| Testing | testing-standards, playwright, bruno | — |
| Review | security (checklist), conventional-commit | — |
| Deploy | pipeline, cdk | — |
| Monitor | monitoring | — |
| Local dev | local-dev | — |
| Compounding | evolve | — |

Flag any stage with no background skill coverage.

---

## Step 3 — Audit agents against their charters

For each agent, answer:
1. Is the agent's trigger description specific enough that Claude picks it reliably?
2. Does the agent's output format match what downstream commands expect?
3. Are there tasks users do manually that this agent should handle?

Check agent files:
```bash
ls agents/
```

Read each agent file and assess against these criteria.

---

## Step 4 — Cross-reference against awesome-copilot

Check if any of these high-value patterns are missing from the plugin's skills:

- `create-architectural-decision-record` → Do we have an ADR skill?
- `threat-model-analyst` → Is the security skill deep enough for threat modelling?
- `refactor-plan` → Do we have a systematic refactor workflow?
- `breakdown-feature-implementation` → Does `/design` produce granular enough tasks?
- `first-ask` → Do agents clarify ambiguous requests before acting?
- `what-context-needed` → Do agents identify missing context before starting?

---

## Step 5 — Produce the EVOLVE report

ultrathink

Write to `docs/evolve/EVOLVE-<date>.md`:

```markdown
# Plugin Evolution Report — <date>

## Evidence summary
- Review reports analysed: N
- Debug reports analysed: N
- Recurring issue categories: [list]

## Skill improvements (prioritised)

### 1. [Skill name] — [High/Medium/Low impact]
**Problem:** [What the evidence shows is missing or wrong]
**Specific change:** [Exact rule, example, or section to add/update]
**Evidence:** [Which REVIEW or DEBUG file showed this]

### 2. ...

## New skills recommended

### [Skill name]
**Why:** [What gap it fills]
**Trigger:** [When Claude should load it]
**Core content:** [3–5 bullet points of what it should cover]

## Agent improvements

### [Agent name]
**Problem:** [What the evidence shows]
**Change:** [Specific prompt or output format change]

## Cross-reference gaps
- Skills missing Related: links: [list]
- SDLC stages with no skill coverage: [list]

## Recommended action order
1. [Highest impact change — can be done now]
2. ...
```

---

## Step 6 — Offer to implement

After writing the report, ask:

> I've written the evolution report to `docs/evolve/EVOLVE-<date>.md`.
>
> Found N improvements. The highest-impact ones are:
> 1. [summary]
> 2. [summary]
>
> Implement them now? (yes / pick numbers / no)

If yes or numbers given — implement the selected improvements directly:
- Update the relevant SKILL.md and content files
- Commit with `chore(evolve): [description of improvement]`
- Update cross-references in related skills
