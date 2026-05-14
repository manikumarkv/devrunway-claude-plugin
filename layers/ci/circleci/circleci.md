# CircleCI Standards

---

## Full config template

```yaml
# .circleci/config.yml
version: 2.1

# ── Orbs ──────────────────────────────────────────────────────────────────────
orbs:
  node: circleci/node@5
  aws-cli: circleci/aws-cli@4

# ── Executors ─────────────────────────────────────────────────────────────────
executors:
  node-executor:
    docker:
      - image: cimg/node:20.18
    working_directory: ~/app
    resource_class: medium

  node-with-postgres:
    docker:
      - image: cimg/node:20.18
      - image: cimg/postgres:16.4
        environment:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
    working_directory: ~/app

# ── Commands ──────────────────────────────────────────────────────────────────
commands:
  install-deps:
    description: Install Node.js dependencies with caching
    steps:
      - restore_cache:
          keys:
            - v1-deps-{{ checksum "package-lock.json" }}
            - v1-deps-              # fallback
      - run:
          name: Install dependencies
          command: npm ci
      - save_cache:
          key: v1-deps-{{ checksum "package-lock.json" }}
          paths:
            - node_modules

# ── Jobs ──────────────────────────────────────────────────────────────────────
jobs:
  lint:
    executor: node-executor
    steps:
      - checkout
      - install-deps
      - run:
          name: Lint
          command: npm run lint
      - run:
          name: Type check
          command: npm run typecheck

  test:
    executor: node-with-postgres
    environment:
      DATABASE_URL: postgresql://test:test@localhost:5432/testdb
    steps:
      - checkout
      - install-deps
      - run:
          name: Run tests with coverage
          command: npm run test:coverage
      - store_test_results:
          path: coverage/junit
      - store_artifacts:
          path: coverage
          destination: coverage

  build:
    executor: node-executor
    steps:
      - checkout
      - install-deps
      - run:
          name: Build
          command: npm run build
      - persist_to_workspace:
          root: ~/app
          paths:
            - dist
            - node_modules

  deploy-staging:
    executor: node-executor
    steps:
      - attach_workspace:
          at: ~/app
      - aws-cli/setup
      - run:
          name: Deploy to staging
          command: |
            aws s3 sync dist/ s3://$STAGING_S3_BUCKET --delete
            aws cloudfront create-invalidation --distribution-id $STAGING_CF_ID --paths "/*"

  deploy-production:
    executor: node-executor
    steps:
      - attach_workspace:
          at: ~/app
      - aws-cli/setup
      - run:
          name: Deploy to production
          command: |
            aws s3 sync dist/ s3://$PRODUCTION_S3_BUCKET --delete
            aws cloudfront create-invalidation --distribution-id $PRODUCTION_CF_ID --paths "/*"

# ── Workflows ─────────────────────────────────────────────────────────────────
workflows:
  ci-cd:
    jobs:
      - lint
      - test
      - build:
          requires:
            - lint
            - test
          filters:
            branches:
              only:
                - main
                - staging
      - deploy-staging:
          requires:
            - build
          context: staging-credentials   # CircleCI Context with secrets
          filters:
            branches:
              only: staging
      - approve-production:
          type: approval     # requires manual click in CircleCI UI
          requires:
            - build
          filters:
            branches:
              only: main
      - deploy-production:
          requires:
            - approve-production
          context: production-credentials
          filters:
            branches:
              only: main
```

---

## Caching

```yaml
# Restore before install; save after
- restore_cache:
    keys:
      - v2-npm-{{ checksum "package-lock.json" }}   # exact match first
      - v2-npm-                                       # fallback: any recent cache
- run: npm ci
- save_cache:
    key: v2-npm-{{ checksum "package-lock.json" }}
    paths:
      - ~/.npm    # npm's global cache (faster than node_modules for monorepos)
      - node_modules
```

**Version prefix strategy:**
```yaml
# When you need to bust the cache (changed Node version, corrupted cache):
# Bump v1 → v2 in the cache key
key: v2-npm-{{ checksum "package-lock.json" }}
```

**Multiple caches in one job:**
```yaml
- restore_cache:
    keys:
      - v1-npm-{{ checksum "package-lock.json" }}
- restore_cache:
    keys:
      - v1-playwright-{{ checksum "package-lock.json" }}
- run: npm ci
- run: npx playwright install --with-deps
- save_cache:
    key: v1-npm-{{ checksum "package-lock.json" }}
    paths: [node_modules]
- save_cache:
    key: v1-playwright-{{ checksum "package-lock.json" }}
    paths: [~/.cache/ms-playwright]
```

---

## Workspaces — passing data between jobs

```yaml
build:
  steps:
    - checkout
    - run: npm run build
    - persist_to_workspace:
        root: .                  # workspace root
        paths:
          - dist/                # relative to root
          - .next/
          - node_modules/

deploy:
  steps:
    - attach_workspace:
        at: .     # attach at working directory
    - run: ls dist/   # available here without re-installing
```

Workspace vs artifacts:
- **Workspace**: share files between jobs in the same workflow — temporary
- **Artifacts**: store files long-term for download/review — persisted after workflow

---

## Environment variables and Contexts

**Project environment variables** (Settings → Project Settings → Environment Variables):
- Project-specific secrets
- Available to all jobs in the project

**Contexts** (Organization Settings → Contexts):
- Group related secrets (e.g. `aws-production`, `staging-credentials`)
- Can be restricted to specific branches
- Shared across multiple projects

```yaml
# Use a context in a job
deploy-production:
  context:
    - aws-credentials      # provides AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
    - production-config    # provides PRODUCTION_S3_BUCKET, etc.
```

**Never in `config.yml`:**
```yaml
# ❌ Hardcoded secret
environment:
  AWS_SECRET_ACCESS_KEY: "abc123..."  # visible in git history
```

---

## Orbs — reuse common integrations

```yaml
orbs:
  node:      circleci/node@5
  aws-cli:   circleci/aws-cli@4
  docker:    circleci/docker@2
  slack:     circleci/slack@4

# Use orb commands in jobs
jobs:
  deploy:
    steps:
      - aws-cli/setup:           # orb command — sets up AWS CLI with credentials
          role-arn: $AWS_ROLE_ARN
      - slack/notify:            # notify Slack on failure
          event: fail
          template: basic_fail_1
```

Find orbs: [circleci.com/developer/orbs](https://circleci.com/developer/orbs)

---

## Parallel test splitting

```yaml
test:
  parallelism: 4    # split tests across 4 containers
  steps:
    - checkout
    - install-deps
    - run:
        name: Split and run tests
        command: |
          TESTFILES=$(circleci tests glob "src/**/*.test.ts" | circleci tests split --split-by=timings)
          npx jest $TESTFILES --reporters=default --reporters=jest-junit
    - store_test_results:
        path: reports
```

---

## Docker build and push

```yaml
orbs:
  docker: circleci/docker@2

jobs:
  docker-build:
    machine:
      image: ubuntu-2204:current
    steps:
      - checkout
      - docker/check:           # verify Docker Hub credentials
          registry: $DOCKER_REGISTRY
      - docker/build:
          image: $IMAGE_NAME
          tag: $CIRCLE_SHA1
      - docker/push:
          image: $IMAGE_NAME
          tag: $CIRCLE_SHA1
```

---

## Common mistakes

| Mistake | Fix |
|---|---|
| No `restore_cache` before install | Always restore before installing; save after |
| Cache key without lockfile checksum | `{{ checksum "package-lock.json" }}` — invalidates when deps change |
| Running lint and test sequentially | They're independent — run in parallel |
| Secrets in `config.yml` | Use Project env vars or Contexts |
| No `store_test_results` | CircleCI can't show test pass/fail in UI without it |
| Production deploy without approval | Add an `approval` job as a manual gate |
