# GitLab CI/CD Standards

---

## Full pipeline template

```yaml
# .gitlab-ci.yml
image: node:20-alpine

stages:
  - validate
  - test
  - build
  - deploy

variables:
  NODE_ENV: test
  FF_USE_FASTZIP: "true"     # faster artifact compression

# ── Cache ─────────────────────────────────────────────────────────────────────
.node_cache: &node_cache
  cache:
    key:
      files:
        - package-lock.json   # invalidate cache when lockfile changes
    paths:
      - node_modules/
    policy: pull-push        # pull at start, push at end

# ── Install ───────────────────────────────────────────────────────────────────
install:
  stage: validate
  <<: *node_cache
  script:
    - npm ci
  artifacts:
    paths:
      - node_modules/
    expire_in: 1 hour

# ── Validate stage ────────────────────────────────────────────────────────────
lint:
  stage: validate
  needs: [install]
  script:
    - npm run lint
    - npm run format:check

typecheck:
  stage: validate
  needs: [install]
  script:
    - npm run typecheck

# ── Test stage ────────────────────────────────────────────────────────────────
unit-test:
  stage: test
  needs: [install]
  script:
    - npm run test:coverage
  coverage: '/Lines\s*:\s*(\d+(?:\.\d+)?)%/'   # parse coverage from output
  artifacts:
    when: always
    paths:
      - coverage/
    reports:
      junit: coverage/junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
    expire_in: 7 days

# ── Build stage ───────────────────────────────────────────────────────────────
build:
  stage: build
  needs: [unit-test, lint, typecheck]
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 day
  rules:
    - if: '$CI_COMMIT_BRANCH == "main" || $CI_COMMIT_BRANCH == "staging"'

# ── Docker build ──────────────────────────────────────────────────────────────
docker-build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
    IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  needs: [unit-test, lint, typecheck]
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG
    - docker tag $IMAGE_TAG $CI_REGISTRY_IMAGE:latest
    - docker push $CI_REGISTRY_IMAGE:latest
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

# ── Deploy stage ──────────────────────────────────────────────────────────────
deploy-staging:
  stage: deploy
  needs: [docker-build]
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - echo "Deploy to staging"
    # e.g.: kubectl set image deployment/api api=$IMAGE_TAG
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

deploy-production:
  stage: deploy
  needs: [deploy-staging]
  environment:
    name: production
    url: https://example.com
  script:
    - echo "Deploy to production"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
  when: manual   # require explicit approval before deploying to production
```

---

## Rules — the right way to control when jobs run

```yaml
# ✅ Use rules (flexible, composable)
rules:
  - if: '$CI_COMMIT_BRANCH == "main"'
    when: always
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    when: always
  - when: never      # skip for all other cases

# Rules with changes (only run if relevant files changed)
rules:
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    changes:
      - src/**/*
      - package*.json
  - when: never

# ❌ Don't use only/except — deprecated approach
only:
  - main
```

---

## Variables — secrets management

```yaml
# .gitlab-ci.yml — safe to commit
variables:
  NODE_ENV: production
  LOG_LEVEL: info

# ❌ Never put secrets in .gitlab-ci.yml
# AWS_SECRET_ACCESS_KEY: "..."   ← never!
```

Set secrets in **Settings → CI/CD → Variables**:
- Check **Masked** — hides the value in job logs
- Check **Protected** — only available on protected branches (main, staging)
- Use **File** type for multi-line secrets (private keys, JSON credentials)

```yaml
# Access in scripts — GitLab injects CI/CD variables automatically
script:
  - echo "Deploying to $ENVIRONMENT"  # safe to log non-secret vars
  - aws s3 sync dist/ s3://$S3_BUCKET  # $AWS_ACCESS_KEY_ID auto-injected
```

---

## Caching strategies

```yaml
# Node.js — cache node_modules, key on lockfile
cache:
  key:
    files:
      - package-lock.json
  paths:
    - node_modules/
  policy: pull-push    # pull at job start, push at job end

# Python — cache virtual environment
cache:
  key:
    files:
      - requirements.txt
  paths:
    - .venv/
  policy: pull-push

# Per-branch cache (avoids branches invalidating each other)
cache:
  key: "$CI_COMMIT_REF_SLUG"
  paths:
    - node_modules/
```

---

## Artifacts — passing data between stages

```yaml
build:
  artifacts:
    paths:
      - dist/
      - .next/        # Next.js output
    expire_in: 1 day   # always set expire_in

unit-test:
  artifacts:
    when: always    # upload even if tests fail (to see failure report)
    reports:
      junit: reports/junit.xml
      coverage_report:
        coverage_format: cobertura
        path: reports/cobertura.xml
    paths:
      - coverage/
    expire_in: 7 days

# Access artifacts from a previous stage
deploy:
  needs:
    - job: build
      artifacts: true   # download build artifacts
  script:
    - ls dist/   # available here
```

---

## Environments and deployments

```yaml
deploy-staging:
  environment:
    name: staging
    url: https://staging.example.com
    on_stop: stop-staging    # optional: auto-stop environment

stop-staging:
  environment:
    name: staging
    action: stop
  when: manual
  script:
    - echo "Destroying staging environment"

# Review apps — per-MR environments
deploy-review:
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_COMMIT_REF_SLUG.review.example.com
    on_stop: stop-review
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

---

## Security scanning

GitLab includes built-in security scanners (available on Ultimate; some on Free):

```yaml
include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Dependency-Scanning.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml

# These auto-add jobs to your pipeline; results appear in Security Dashboard
```

---

## Common patterns

```yaml
# Reusable job templates with extends
.base-test:
  stage: test
  needs: [install]
  before_script:
    - npm ci

unit-test:
  extends: .base-test
  script:
    - npm test

integration-test:
  extends: .base-test
  script:
    - npm run test:integration

# Parallel matrix — test against multiple versions
test:
  parallel:
    matrix:
      - NODE_VERSION: ["18", "20", "22"]
  image: node:${NODE_VERSION}-alpine
  script:
    - node --version
    - npm test

# Trigger another project's pipeline
trigger-downstream:
  trigger:
    project: mygroup/another-project
    branch: main
    strategy: depend   # wait for downstream pipeline to complete
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Secrets in `.gitlab-ci.yml` | Use CI/CD Variables (Settings → CI/CD → Variables) |
| `only: master` | Use `rules: if: '$CI_COMMIT_BRANCH == "main"'` |
| No `expire_in` on artifacts | Set expire_in — unbounded artifacts consume storage |
| No `needs:` — sequential by stage only | Use `needs:` to express dependencies and run jobs sooner |
| No `when: manual` on production deploy | Require explicit approval for production deployments |
