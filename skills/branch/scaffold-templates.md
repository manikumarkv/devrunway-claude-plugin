# Branch Scaffold Templates

Universal pseudocode templates for `/branch create` scaffolding.

**Replace with your stack's actual syntax.** Consult your installed **frontend layer** and **backend layer** skills for language-specific implementations (TypeScript/React, Python/FastAPI, C#/.NET, etc.).

Replace `$NAME` with PascalCase resource name, `$name` with camelCase.

---

## Frontend Feature Scaffold

Directory: `src/features/<name>/`

### `types.<ext>` — Data types

```
interface $NAME:
  id: string (unique identifier)
  createdAt: timestamp
  updatedAt: timestamp
  // TODO: add domain fields

interface Create$NAMEInput:
  // TODO: add required input fields
```

### `api/$name.api.<ext>` — Data fetching

```
// List query
function use$NAMEs():
  fetch GET /api/v1/$name
  return list of $NAME

// Single record query
function use$NAME(id):
  fetch GET /api/v1/$name/:id
  return single $NAME

// Create mutation
function useCreate$NAME():
  POST /api/v1/$name with input
  on success: invalidate list query
```

### `hooks/use$NAME.<ext>` — Business logic hook

```
function use$NAME():
  items, isLoading, error = use$NAMEs()
  create = useCreate$NAME()
  return { items, isLoading, error, create }
```

### `components/$NAME/$NAME.<ext>` — UI component

```
component $NAME:
  { items, isLoading, error } = use$NAME()

  if isLoading: render loading state
  if error: render error state
  if items is empty: render empty state
  else: render items list
```

### `components/$NAME/$NAME.test.<ext>` — Component tests

```
describe '$NAME':
  it 'renders loading state while fetching'
    // mock loading — assert loading indicator visible

  it 'renders items when loaded'
    // mock success response — assert items appear

  it 'renders empty state when no items'
    // mock empty response — assert empty message visible

  it 'renders error state on fetch failure'
    // mock error response — assert error message visible
```

### `components/$NAME/index.<ext>` — Barrel export

```
export $NAME from ./$NAME
```

### `index.<ext>` — Feature public API

```
export $NAME from ./components/$NAME
export use$NAME from ./hooks/use$NAME
export type $NAME, Create$NAMEInput from ./types
```

---

## Backend API Endpoint Scaffold

### `src/types/$name.types.<ext>` — Validation schemas + types

```
schema Create$NAMESchema:
  // TODO: add required fields with types and constraints
  // e.g. name: string, required, non-empty
  //      ownerId: string, required, uuid

schema $NAMEParamsSchema:
  id: string, required, uuid

type Create$NAMEInput = inferred from Create$NAMESchema
```

_(Use your validation layer: Zod, Pydantic, Joi, FluentValidation, etc.)_

### `src/repositories/$name.repository.<ext>` — Data access

```
repository $nameRepository:

  function findAll(): list of $NAME
    log debug: action=findAll$NAME
    // TODO: query database

  function findById(id): $NAME or null
    log debug: action=findById$NAME, id=id
    // TODO: query database by primary key

  function create(input: Create$NAMEInput): $NAME
    log debug: action=create$NAME
    // TODO: insert into database
```

_(Use your database layer: Prisma, SQLAlchemy, Entity Framework, etc.)_

### `src/services/$name.service.<ext>` — Business logic

```
service $nameService:

  function getAll(callerId): list of $NAME
    log info: userId=callerId, action=getAll$NAME
    return $nameRepository.findAll()

  function getById(id, callerId): $NAME
    item = $nameRepository.findById(id)
    if item is null:
      log warn: userId=callerId, action=getById$NAME, id=id
      throw NotFoundError($NAME, id)
    return item

  function create(input, callerId): $NAME
    log info: userId=callerId, action=create$NAME
    return $nameRepository.create(input)
```

### `src/controllers/$name.controller.<ext>` — Request handling

```
router $nameRouter:
  all routes require: authMiddleware

  GET /
    callerId = request.user.id
    data = $nameService.getAll(callerId)
    log info: userId=callerId, action=list$NAME, count=data.length
    respond 200: { success: true, data }

  GET /:id
    id = validate $NAMEParamsSchema(request.params)
    callerId = request.user.id
    data = $nameService.getById(id, callerId)
    respond 200: { success: true, data }

  POST /
    input = validate Create$NAMESchema(request.body)
    callerId = request.user.id
    data = $nameService.create(input, callerId)
    log info: userId=callerId, action=create$NAME, id=data.id
    respond 201: { success: true, data }
```

_(Use your backend layer: Express/asyncHandler, FastAPI, ASP.NET controllers, etc.)_

---

> **Tech-specific templates:** See your installed layer skills for framework-specific code.
> - Frontend: `layers/frontend/<your-stack>/`
> - Backend: `layers/backend/<your-stack>/`
