# Changelog

All notable changes to devrunway are documented here. This project follows [Semantic Versioning](https://semver.org/).

## [4.1.0] — 2026-09-19

### Features

- **skills**: add the security-principles skill that 24 files already reference (8584621)
- **skills**: add naming-conventions skill and wire into code review (57bf0e0)
- **skills**: add six Flutter slash commands; complete the build (287708e)
- **layers**: declare scope on layers that collide on shared globs (ff28def)
- **layer**: add mobile/flutter layer for structure, bootstrap and theming (0d53f6d)
- **layer**: add riverpod layer for Flutter state standards (cca9bda)
- **layer**: add dio layer for Flutter API service standards (163464c)
- **layer**: add go-router layer for Flutter navigation standards (a8b4de5)
- **layer**: add dart-models layer for Flutter model standards (8ce7f45)
- **layer**: add flutter-ui layer for Flutter widget standards (a693cb3)
- **layer**: add flutter-test layer for Flutter testing standards (9a549dc)
- **layer**: add flutter-session layer for Flutter auth standards (4c47518)
- **layer**: add flutter-local layer for on-device storage standards (fa192e3)
- **layer**: add flutter-l10n layer for localization standards (6a0f22c)
- **layer**: add flutter-observability layer for logging, analytics and flags (c295d9b)
- **layer**: add flutter-release layer for flavor and CI standards (39a8958)
- **layer**: add fcm layer for push notification standards (e9e5f0e)
- **layer**: add neon and neon-branching layers (81eb1a2)

### Bug Fixes

- **plugin**: repair layer discovery — depth cap and corrupt frontmatter (0f2b029)
- **layers**: narrow catch-all globs so specific layers win the dispatch (8d0a612)
- **layers**: merge duplicate api-docs and swagger-docs into one layer (de5d36c)
- **agents**: dispatcher carries layer scope lines into dispatch result (660717d)
- **layers**: stripe — re-price server-side, ack webhook after fulfil (1bcdb91)
- **layers**: paypal — server-side amount, auth, and capture idempotency (f18fabd)
- **layers**: braintree — verify webhook before ack, check the response (f5b90a2)
- **layers**: vault — renew the credential lease, not just the token (225fa4b)
- **layers**: aws-secrets-manager — stop the config object printing its secrets (22ae263)
- **layers**: env-only — make the config object safe to print (4c71ed3)
- **layers**: cloudinary — derive the signed upload path from the session (2f17398)
- **layers**: flagsmith — keep the browser key and the browser SDK off the server (076e2bb)
- **layers**: redux-toolkit — authenticate baseQuery with the session cookie (5406c44)
- **layers**: reconcile composition-patterns with react-standards (eaedc0a)
- **layers**: give the Cognito LoginForm real labels (753f347)
- **layers**: put dotnet and azure-ad on the api-conventions envelope (e5f2fd1)
- **layers**: make the pino auth logs and the CloudWatch query agree (689c843)
- **layers**: conform the Flutter set to conventions landed on main (cc6fb6f)
- **layers**: reconcile analysis_options ownership and the custom_lint gate (475101d)
- **layers**: repair defects the consultant-path eval run exposed (0c4abd7)
- **layer**: stop Neon §2 contradicting §3 on serverless Pool lifecycle (914603f)
- **layer**: secretKeyRef takes name:, not secretName: (298381d)
- **layer**: drop CloudWatch sequenceToken, removed from PutLogEvents in 2023 (26f377e)
- **layer**: make LaunchDarkly's TestData section actually use TestData (76a4511)
- **layer**: move gRPC reserved statements inside the message body (acfb839)
- **layer**: register Mirage traits with trait(), not a withTrait map (94b00e1)
- **layer**: teach Winston's real signature, not Pino's (792204b)
- **layer**: close the replay-path deadlock gap in flutter-session (e1936b4)
- **layer**: make dio eval assertions discriminate (1435e3a)
- **layer**: reconcile error-handling summary, detail file, and envelope (80c7cf7)
- **hooks**: validate SKILL.md and eval frontmatter on write (f215478)
- **hooks**: resolve branch from the project dir, not ambient cwd (ca7f9f4)
- **eval**: scope eval discovery to the source tree, not git worktrees (1bbdc10)
- **eval**: repair nine payment and Group 2 cases that passed without discriminating (9f0e310, 5b44d0d, 9c7f1db)
- **eval**: repair two assertions that contradicted their own layer (21367a7)
- **eval**: list detail files in skill_files across the suite (2edb642)
- **eval**: repair defective neon assertions, ignore generated reports (1ce05e0)

### Documentation & Tests

- **adr**: ADR 0001 — layer glob collision and dispatcher routing policy (cb131d8)
- **layers**: add authoring guide and 19 build briefs for Flutter layers (54de359)
- **layers**: mark brief eval tables as sketches, ban prose assertions (1f5107c)
- **layers**: record the flutter-ui split decision, sharpen eval guidance (3cd5531)
- **layers**: shared status tables belong to the coordinator (2839a7f)
- **layers**: phase 1-3 and phase 4 progress; discrimination-proof requirement (e940609, b41d894)
- **contributing**: record why a green eval suite proves nothing (9222344)
- **skills**: add Avoid sections to standards and api-conventions (79e7a1f)
- **claude-md**: stop documenting cognito-auth as an auto-loading layer (5aaf57c)
- **dispatcher**: add regression cases for depth cap and unroutable layers (b3204d7)
- **layer**: close a coverage gap in the mobile/flutter theming eval (7e9030b)

[4.1.0]: https://github.com/manikumarkv/devrunway-claude-plugin/compare/v4.0.5...v4.1.0
