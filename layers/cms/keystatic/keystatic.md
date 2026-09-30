# Keystatic standards

Short rules for projects that manage content with [Keystatic](https://keystatic.com), a git-based CMS: entries are files (Markdoc, MDX, YAML, JSON) committed to the repo.

## 1. Config

- Keep one `keystatic.config.ts` at the project root.
- Use a **collection** for many entries of one type, and a **singleton** for one-off content.
- Set `path` so files land where the site reads them, and `format` to match (`{ contentField: 'content' }` for Markdoc/MDX bodies, `{ data: 'yaml' }` for data-only).

```ts
import { config, collection, singleton, fields } from '@keystatic/core';

export default config({
  storage: import.meta.env.PROD ? { kind: 'github', repo: 'owner/repo' } : { kind: 'local' },
  collections: {
    terms: collection({
      label: 'Terms',
      slugField: 'title',
      path: 'src/content/terms/*',
      format: { contentField: 'body' },
      schema: {
        title: fields.slug({ name: { label: 'Term', validation: { isRequired: true } } }),
        difficulty: fields.select({
          label: 'Difficulty',
          options: [
            { label: 'Beginner', value: 'beginner' },
            { label: 'Intermediate', value: 'intermediate' },
            { label: 'Advanced', value: 'advanced' },
          ],
          defaultValue: 'beginner',
        }),
        related: fields.array(fields.relationship({ label: 'Related', collection: 'terms' }), { label: 'Related terms' }),
        body: fields.markdoc({ label: 'Definition' }),
      },
    }),
  },
  singletons: {
    settings: singleton({ label: 'Site settings', path: 'src/content/settings', schema: { siteName: fields.text({ label: 'Site name' }) } }),
  },
});
```

## 2. Fields

- `fields.slug` for the entry's name. It also sets the file name.
- `fields.select` for fixed values, never free text.
- `fields.relationship` to link entries. Editors then pick from a list and can't mistype.
- Set `validation: { isRequired: true }` (or `length` limits) on everything the site needs.
- Give every field a clear `label` and a `description` when editors could get it wrong.

## 3. Keep schemas in step

- If Astro content collections (or Zod in Next.js) also validate these files, the two schemas must describe the same fields and values.
- Change both in the same commit. A mismatch shows up as a build failure after an editor saves.

## 4. Reading content

- In Astro, read the files through content collections.
- Elsewhere, use the Reader API on the server: `createReader(process.cwd(), keystaticConfig)`.
- Don't import content files directly from components.

## 5. Storage and auth

| Mode | Use |
|---|---|
| `local` | Local dev, one editor. Writes to the working tree. |
| `github` | A team editing in production. Saves become commits or PRs. Needs a GitHub App. |
| `cloud` | Keystatic Cloud handles auth and images. |

- In `github` mode, `KEYSTATIC_GITHUB_CLIENT_ID`, `KEYSTATIC_GITHUB_CLIENT_SECRET` and `KEYSTATIC_SECRET` are server-only secrets.
- With `local` storage in production the admin route has no auth: exclude it from the production build or switch modes.

## Never

- Free-text fields for values the site switches on (use `select`).
- Two schemas for the same content that disagree.
- The admin UI in production without auth.
- Keystatic secrets in `PUBLIC_` or `NEXT_PUBLIC_` variables.
