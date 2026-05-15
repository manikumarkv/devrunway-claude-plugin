# gRPC Standards

## Proto File Layout

```proto
// users/v1/user_service.proto
syntax = "proto3";

package users.v1;

option go_package = "github.com/example/users/v1;usersv1";

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  rpc ListUsers(ListUsersRequest) returns (stream UserEvent);  // server-streaming
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
  rpc DeleteUser(DeleteUserRequest) returns (google.protobuf.Empty);
}

message GetUserRequest {
  string user_id = 1;
}

message GetUserResponse {
  User user = 1;
}

message User {
  string id = 1;
  string email = 2;
  string name = 3;
  google.protobuf.Timestamp created_at = 4;
  // field 5 was "phone" — now reserved
}

// Never reuse field numbers
reserved 5;
reserved "phone";

message CreateUserRequest {
  string email = 1;
  string name = 2;
}

message CreateUserResponse {
  User user = 1;
}

message DeleteUserRequest {
  string user_id = 1;
}

message ListUsersRequest {
  int32 page_size = 1;
  string page_token = 2;
}

message UserEvent {
  User user = 1;
}
```

## buf.yaml + buf.gen.yaml

```yaml
# buf.yaml
version: v1
lint:
  use:
    - DEFAULT
breaking:
  use:
    - FILE
```

```yaml
# buf.gen.yaml
version: v1
plugins:
  - plugin: buf.build/protocolbuffers/python
    out: gen/python
  - plugin: buf.build/grpc/python
    out: gen/python
```

```bash
# CI commands
buf lint
buf breaking --against '.git#branch=main'
buf generate
```

## Python Server with Interceptors

```python
# server.py
import grpc
from concurrent import futures
from grpc_interceptor import ServerInterceptor
from users.v1 import user_service_pb2_grpc
from app.services import UserServiceImpl

class AuthInterceptor(ServerInterceptor):
    def intercept(self, method, request, context, method_name):
        metadata = dict(context.invocation_metadata())
        token = metadata.get("authorization", "").removeprefix("Bearer ")
        if not verify_token(token):
            context.abort(grpc.StatusCode.UNAUTHENTICATED, "Invalid token")
            return
        return method(request, context)

class LoggingInterceptor(ServerInterceptor):
    def intercept(self, method, request, context, method_name):
        import time, logging
        start = time.perf_counter()
        result = method(request, context)
        elapsed = (time.perf_counter() - start) * 1000
        logging.info("grpc method=%s latency_ms=%.1f", method_name, elapsed)
        return result

def serve():
    interceptors = [AuthInterceptor(), LoggingInterceptor()]
    server = grpc.server(
        futures.ThreadPoolExecutor(max_workers=10),
        interceptors=interceptors,
    )
    user_service_pb2_grpc.add_UserServiceServicer_to_server(UserServiceImpl(), server)
    server.add_insecure_port("[::]:50051")
    server.start()
    server.wait_for_termination()
```

## Python Client with Deadline

```python
# client.py
import grpc
from users.v1 import user_service_pb2, user_service_pb2_grpc

channel = grpc.secure_channel("users-service:50051", grpc.ssl_channel_credentials())
stub = user_service_pb2_grpc.UserServiceStub(channel)

# Always set a deadline
response = stub.GetUser(
    user_service_pb2.GetUserRequest(user_id="abc-123"),
    timeout=5.0,  # seconds
    metadata=[("authorization", f"Bearer {token}")],
)
```

## Error Status Codes

```python
from grpc import StatusCode

# In a servicer method
def GetUser(self, request, context):
    user = db.find(request.user_id)
    if user is None:
        context.abort(StatusCode.NOT_FOUND, f"User {request.user_id} not found")
        return

# Mapping table
# Domain condition          → gRPC code
# Entity not found          → NOT_FOUND
# Bad input                 → INVALID_ARGUMENT
# Already exists            → ALREADY_EXISTS
# No permission             → PERMISSION_DENIED
# Not logged in             → UNAUTHENTICATED
# Rate limit                → RESOURCE_EXHAUSTED
# Transient backend error   → UNAVAILABLE (client should retry)
# Bug / unexpected          → INTERNAL (never UNKNOWN)
```

## Node.js Client

```typescript
import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";

const packageDef = protoLoader.loadSync("users/v1/user_service.proto", {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});
const proto = grpc.loadPackageDefinition(packageDef) as any;

const client = new proto.users.v1.UserService(
  "users-service:50051",
  grpc.credentials.createSsl(),
);

// Deadline
const deadline = new Date();
deadline.setSeconds(deadline.getSeconds() + 5);

client.getUser({ user_id: "abc-123" }, { deadline }, (err: Error, response: any) => {
  if (err) throw err;
  console.log(response.user);
});
```

## Checklist

- [ ] `buf lint` passes with DEFAULT ruleset
- [ ] `buf breaking` runs in CI against main branch
- [ ] Generated files excluded from git (`.gitignore`)
- [ ] Auth interceptor validates JWT on every server call
- [ ] All client calls have explicit timeouts
- [ ] Domain errors mapped to specific gRPC status codes (not UNKNOWN)
- [ ] Deleted proto fields marked with `reserved`

## Common mistakes

| Mistake | Fix |
|---|---|
| Reusing a deleted field number | Mark removed fields with `reserved 5; reserved "phone";` — never reassign numbers |
| Returning `UNKNOWN` for domain errors | Map domain conditions to specific codes: `NOT_FOUND`, `INVALID_ARGUMENT`, `ALREADY_EXISTS`, etc. |
| Not setting a client deadline | Always pass `timeout=` (Python) or `{ deadline }` (Node.js) on every stub call |
| Sharing one channel across goroutines/threads unsafely | Create one channel per logical consumer/publisher; channels are not concurrency-safe in amqplib |
| Committing generated protobuf files | Add `gen/` to `.gitignore`; regenerate in CI with `buf generate` |
| Skipping `buf lint` and `buf breaking` in CI | Run both checks on every PR to catch style violations and breaking schema changes early |
| Using insecure channels in production | Use `grpc.ssl_channel_credentials()` / `grpc.credentials.createSsl()` — never `insecure_channel` outside local dev |
| Missing `reserved` when removing an enum value | Enum values also need `reserved` entries to prevent value reuse |
