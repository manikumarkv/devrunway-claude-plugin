---
name: dora
description: Generate a 30-day DORA metrics scorecard — deployment frequency, lead time for changes, change failure rate, and mean time to recovery. Reads git history and GitHub PRs. Usage — /dora [report|trend] [--days N]
argument-hint: "[report|trend] [--days N]"
arguments:
  - name: subcommand
    description: "'report' for current snapshot (default), 'trend' for week-over-week comparison"
  - name: days
    description: "Lookback window in days (default: 30)"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash(git *)
  - Bash(gh *)
  - Bash(date *)
  - Bash(grep *)
  - Bash(awk *)
  - Bash(wc *)
  - Bash(node *)
---

# DORA Metrics

Parse `$ARGUMENTS[0]` as `report` or `trend` (default: `report`).
Parse `--days N` from arguments (default: 30).

DORA (DevOps Research and Assessment) four key metrics measure software delivery performance.
Elite teams deploy multiple times per day with less than 1-hour lead time and <5% failure rate.

---

## Step 1 — Collect raw data

```bash
DAYS=30
SINCE=$(date -v-${DAYS}d +%Y-%m-%d 2>/dev/null || date -d "${DAYS} days ago" +%Y-%m-%d)

echo "=== Period: last ${DAYS} days (since ${SINCE}) ==="

# 1. Production deploy tags (format: deploy/prod/v* or deploy-prod-*)
echo "--- Production deploys ---"
git tag --sort=-creatordate | grep -E 'deploy.?prod|release|^v[0-9]' \
  | while read tag; do
      tag_date=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
      [[ "$tag_date" > "$SINCE" ]] && echo "$tag_date  $tag"
    done

# 2. Merged PRs to main in period
echo "--- Merged PRs ---"
gh pr list --state merged --base main --limit 100 \
  --json number,title,mergedAt,createdAt,headRefName \
  --jq ".[] | select(.mergedAt > \"${SINCE}\") | [.number, .mergedAt, .createdAt, .headRefName] | @tsv" \
  2>/dev/null | head -50

# 3. Hotfix / rollback events
echo "--- Rollbacks / hotfixes ---"
git tag --sort=-creatordate | grep -iE 'rollback|hotfix|revert' \
  | while read tag; do
      tag_date=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1)
      [[ "$tag_date" > "$SINCE" ]] && echo "$tag_date  $tag"
    done

# Also check for hotfix PRs/branches
gh pr list --state merged --base main --limit 100 \
  --json number,title,mergedAt,headRefName \
  --jq ".[] | select(.mergedAt > \"${SINCE}\") | select(.headRefName | test(\"hotfix|fix/|patch/\")) | [.number, .mergedAt, .headRefName] | @tsv" \
  2>/dev/null
```

---

## Step 2 — Calculate the four metrics

### Metric 1: Deployment Frequency

Count production deploys in the period.

| Benchmark | Frequency |
|---|---|
| 🏆 Elite | Multiple times per day |
| ✅ High | Once per day to once per week |
| ⚠️ Medium | Once per week to once per month |
| 🔴 Low | Less than once per month |

### Metric 2: Lead Time for Changes

For each merged PR, lead time = time from branch creation (first commit on branch) to production deploy.

```bash
# For each merged PR, find first commit on the branch
gh pr list --state merged --base main --limit 20 \
  --json number,mergedAt,headRefName \
  --jq '.[].headRefName' 2>/dev/null | while read branch; do
    first_commit=$(git log --format="%ai" "origin/$branch" 2>/dev/null | tail -1)
    echo "$branch: first commit $first_commit"
  done
```

Average the lead times. If deploy tags exist, use tag timestamp instead of merge timestamp for production deploy time.

| Benchmark | Lead Time |
|---|---|
| 🏆 Elite | < 1 hour |
| ✅ High | 1 day to 1 week |
| ⚠️ Medium | 1 week to 1 month |
| 🔴 Low | > 1 month |

### Metric 3: Change Failure Rate

`(hotfix PRs + rollback events) / total deploys × 100`

| Benchmark | Failure Rate |
|---|---|
| 🏆 Elite | 0–5% |
| ✅ High | 5–10% |
| ⚠️ Medium | 10–15% |
| 🔴 Low | > 15% |

### Metric 4: Mean Time to Recovery (MTTR)

If rollback tags exist with a corresponding recovery tag: measure the gap.
Otherwise: estimate from PR timestamps (hotfix PR created → hotfix merged).

```bash
# Look for incident/recovery tag pairs
git tag | grep -iE 'incident|outage' | sort
```

If no structured incident tags exist, note that MTTR is unmeasured and recommend tagging incidents.

| Benchmark | MTTR |
|---|---|
| 🏆 Elite | < 1 hour |
| ✅ High | < 1 day |
| ⚠️ Medium | 1 day to 1 week |
| 🔴 Low | > 1 week |

---

## Step 3 — Write the report

Write to `docs/dora/DORA-<YYYY-MM-DD>.md`:

```markdown
# DORA Metrics Report
_Period: <SINCE> → <TODAY> (<DAYS> days)_
_Generated: <TODAY>_

## Scorecard

| Metric | Value | Benchmark | Rating |
|---|---|---|---|
| Deployment Frequency | <N> deploys / <DAYS> days (<rate>/week) | ≥1/day = Elite | 🏆/✅/⚠️/🔴 |
| Lead Time for Changes | <avg> hours/days | <1 hour = Elite | 🏆/✅/⚠️/🔴 |
| Change Failure Rate | <N>% (<hotfixes>/<deploys>) | <5% = Elite | 🏆/✅/⚠️/🔴 |
| Mean Time to Recovery | <avg> or "unmeasured" | <1 hour = Elite | 🏆/✅/⚠️/🔴 |

## Overall Rating: <Elite / High / Medium / Low>
_(Based on the lowest-rated individual metric)_

## Detail

### Deploys in period
| Date | Tag / Release |
|---|---|
| <date> | v1.3.0 |

### Hotfixes / Rollbacks
| Date | PR / Tag | Recovery time |
|---|---|---|
| <date> | fix/auth-timeout | 2h 15m |

### Slowest PRs (lead time outliers)
| PR | Branch | Lead time | Reason |
|---|---|---|---|
| #42 | feat/123-payments | 12 days | blocked on API keys |

## Recommendations

<Based on the lowest-scoring metric, give 1–3 specific actionable recommendations>

### To improve Deployment Frequency
- Break large features into smaller PRs (current avg PR size: X files changed)
- Consider trunk-based development with feature flags

### To improve Lead Time
- Current bottleneck: <where the time is being spent — PR review wait, CI time, staging QA>

### To improve Change Failure Rate
- <specific pattern from the hotfix PRs — e.g., "3 of 4 hotfixes were for missing env vars in prod">

### To improve MTTR
- Add incident tags: when an incident starts, run: `git tag incident/<date>-<description>`
- When resolved: `git tag recovery/<date>-<description>`
- This will make MTTR automatically calculable next report
```

---

## Step 4 — Present summary and recommendations

Show the scorecard in the chat, then:

> DORA report saved to `docs/dora/DORA-<date>.md`
>
> **Overall: <rating>**
> Your weakest metric is **<metric>** — here's what to focus on next:
> <top recommendation>
>
> Run `/dora trend` to compare against previous periods once you have 2+ reports.

---

## `/dora trend`

If 2+ DORA reports exist in `docs/dora/`, compare them:

```bash
find docs/dora/ -name 'DORA-*.md' | sort -r | head -6
```

Show a week-over-week or report-over-report comparison table:

| Metric | Previous | Current | Δ |
|---|---|---|---|
| Deployment Frequency | 2/week | 4/week | ▲ +100% |
| Lead Time | 3 days | 1.5 days | ▲ -50% |
| Change Failure Rate | 12% | 8% | ▲ -4pp |
| MTTR | unmeasured | 4h | — |

**Related skills — apply together:**
- `pipeline` — CI/CD pipeline design directly affects deployment frequency and lead time
- `conventional-commit` — consistent tagging enables automated DORA data collection
- `deploy` — use deploy tags (`git tag deploy/prod/v<version>`) to make frequency measurable
- `evolve` — DORA trends feed the /evolve evidence base for process improvements
