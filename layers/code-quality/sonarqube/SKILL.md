---
name: sonarqube
description: SonarQube/SonarCloud quality gates, coverage upload, sonar-project.properties, CI integration
user-invocable: false
stack: code-quality/sonarqube
paths:
  - "**/sonar-project.properties"
  - "**/.sonarcloud.properties"
  - "**/.github/workflows/*.yml"
  - "**/Jenkinsfile"
  - "**/azure-pipelines.yml"
---

Full standards in [sonarqube.md](sonarqube.md). Always-on summary:

**Quality Gates:**
- Never bypass or disable the quality gate — it is the merge-blocking signal
- Default gate conditions: coverage >= 80%, duplications < 3%, no new critical/blocker issues
- Add project-specific conditions for security hotspots review

**Coverage Upload:**
- Generate coverage reports in your test runner before running the scanner
- Pass `sonar.javascript.lcov.reportPaths` (JS/TS) or `sonar.python.coverage.reportPaths` (Python)
- Coverage must be generated in the same CI step as the scanner, not a previous job

**sonar-project.properties:**
- Set `sonar.projectKey`, `sonar.organization` (SonarCloud), and `sonar.sources`
- Exclude generated code, test fixtures, and vendor dirs with `sonar.exclusions`
- Set `sonar.tests` and `sonar.test.inclusions` to separate test files from source

**CI Integration:**
- Use `SONAR_TOKEN` environment variable — never commit the token
- Run scanner after tests complete — scanner must find existing coverage reports
- On PR branches, set `sonar.pullrequest.key`, `sonar.pullrequest.branch`, and `sonar.pullrequest.base`

**Never:**
- Add `#sonar:off` suppressions without a comment explaining why
- Lower the quality gate to pass a deadline — fix the code
- Scan without coverage — Sonar without coverage data gives misleading quality scores
- Run the scanner on the wrong branch (main scanner runs on integration branches, not feature branches)

**Related skills:** `pipeline`, `linting`, `security-principles`
