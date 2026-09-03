# Brief — `/flutter-submit`

**Kind:** slash command (`skills/flutter-submit/`) · **Issue:** #19 (parent #2) · **Cookbook:** `#submit`

`user-invocable: true`. Sub-commands: `check` (pre-submission audit against the repo),
`triage <rejection text>`.

## Content to encode
1. Run the checklist **before** building the release candidate. None of this is visible from
   the code, and every item takes days to fix if found at submission — when the release is
   already late.
2. **Per-store requirement table:**

   | Requirement | Apple | Google |
   |---|---|---|
   | In-app account deletion | Required if you offer account creation | Required, plus a web deletion URL |
   | Privacy disclosure | Nutrition labels + privacy manifest for certain APIs | Data Safety form |
   | Target SDK / OS | Built with a recent SDK | Annual `targetSdk` deadline |
   | Permissions | A usage string per permission, specific about why | Sensitive-permission declaration |
   | Payments | IAP for digital goods | Play Billing for digital goods |
   | Content rating | Age rating questionnaire | Content rating questionnaire |
   | Test access | Demo account for review | Demo account / testing instructions |

3. **Disclosures must match what the app actually does, including what your SDKs collect.**
   An analytics or ads SDK collecting an undeclared identifier is a rejection, and the
   declaration is your responsibility, not the vendor's. Re-verify whenever a dependency is
   added.
4. **Rejection triage — what each one usually *means*:**

   | Rejection | Usually means |
   |---|---|
   | Incomplete information | The reviewer could not sign in — demo credentials wrong, expired, or two-factor gated |
   | Broken functionality | A crash on the reviewer's OS or region, or a feature behind a flag that was off |
   | Privacy mismatch | Declared collection differs from observed network traffic |
   | Account deletion missing | Deletion is buried, web-only, or "contact support" |
   | Minimum functionality | The app reads as a website wrapper |
   | External payment link | A link out for digital goods |

5. Reply in the review thread with specifics before resubmitting. A bare resubmission gets
   the same reviewer and the same result. Expedited review is remembered — reserve it for
   real emergencies.
6. Nothing user-facing behind a flag that is off during review, unless the reviewer is told
   how to enable it.
7. Store metadata and screenshots are versioned in the repo and generated, not hand-edited in
   two consoles.
8. Submission dates account for review time and for the annual target-SDK deadline — both
   known months ahead.

## Acceptance
- [ ] `check` runs against the actual repo: detects missing usage strings, an absent
      account-deletion route, and a `targetSdk` below the current deadline
- [ ] `check` lists every collecting SDK found in `pubspec.yaml` for disclosure review
- [ ] `triage` maps a pasted rejection to the likely cause and a concrete fix, not a restatement
