---
name: grpc
description: gRPC proto conventions, code-gen, streaming, interceptors, and error codes
user-invocable: false
stack: api-style/grpc
paths:
  - "**/*.proto"
  - "**/proto/**"
  - "**/*_pb2*.py"
  - "**/*.grpc.js"
  - "**/grpc/**"
---

Full standards in [grpc.md](grpc.md). Always-on summary:

**Proto File Conventions:**
- One service per `.proto` file; file name matches service name in snake_case
- Always set `syntax = "proto3"`, `package`, and `option go_package` / `option java_package`
- Use `google.protobuf.Timestamp` for dates, `google.protobuf.Empty` for no-payload methods
- Fields must have explicit field numbers; never reuse a deleted field number — use `reserved`

**Code Generation:**
- Generate code in CI, never commit generated `*_pb2.py` or `*.grpc.js` files
- Pin the `protoc` version and plugin versions in a `buf.gen.yaml` or Makefile
- Use `buf` for linting and breaking change detection: `buf lint && buf breaking`

**Unary vs Streaming:**
- Prefer unary RPCs unless payload is genuinely large or continuous
- Server-streaming for paginated data; bidirectional for real-time collaboration
- Always set deadlines on the client side: `grpc.CallOption` with timeout

**Interceptors:**
- Add auth interceptor server-side to validate JWT on every call
- Add logging interceptor for method, status, and latency
- Chain interceptors: auth → logging → rate-limit

**Error Status Codes:**
- Map domain errors to gRPC status codes: `NOT_FOUND`, `INVALID_ARGUMENT`, `ALREADY_EXISTS`, `PERMISSION_DENIED`, `UNAUTHENTICATED`
- Attach error details with `google.rpc.Status` + `google.rpc.ErrorInfo`
- Never return `UNKNOWN` when a more specific code applies

**Never:**
- Put business logic in proto files (annotations only)
- Commit generated files to source control
- Ignore deadlines — unbounded RPCs exhaust connection pools
- Use field names that differ from the proto spec in hand-written code

**Related skills:** `api-conventions`, `error-handling`, `security-principles`
