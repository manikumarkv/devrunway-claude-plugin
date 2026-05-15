# GCP Standards

## Cloud Run Deployment

```bash
# Build and push to Artifact Registry
gcloud builds submit --tag us-central1-docker.pkg.dev/MY_PROJECT/myapp/api:${GIT_SHA}

# Deploy Cloud Run service
gcloud run deploy myapp-api \
  --image us-central1-docker.pkg.dev/MY_PROJECT/myapp/api:${GIT_SHA} \
  --region us-central1 \
  --service-account myapp-api-sa@MY_PROJECT.iam.gserviceaccount.com \
  --no-allow-unauthenticated \
  --min-instances 1 \
  --max-instances 20 \
  --memory 512Mi \
  --cpu 1 \
  --concurrency 80 \
  --set-env-vars "ENV=production,PROJECT_ID=MY_PROJECT" \
  --set-secrets "DB_PASSWORD=db-password:latest,API_KEY=api-key:latest"
```

## Terraform — Cloud Run + IAM

```hcl
# infra/cloud_run.tf

resource "google_service_account" "myapp_api" {
  account_id   = "myapp-api-sa"
  display_name = "MyApp API Service Account"
}

resource "google_cloud_run_v2_service" "api" {
  name     = "myapp-api"
  location = var.region

  template {
    service_account = google_service_account.myapp_api.email

    scaling {
      min_instance_count = 1
      max_instance_count = 20
    }

    containers {
      image = "us-central1-docker.pkg.dev/${var.project_id}/myapp/api:${var.image_tag}"

      resources {
        limits = {
          memory = "512Mi"
          cpu    = "1"
        }
      }

      env {
        name  = "ENV"
        value = "production"
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
    }
  }
}

# Grant the SA access to its secrets
resource "google_secret_manager_secret_iam_member" "db_password_accessor" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.myapp_api.email}"
}
```

## Secret Manager

```bash
# Create a secret
gcloud secrets create db-password --replication-policy=automatic

# Add a version
echo -n "supersecret" | gcloud secrets versions add db-password --data-file=-

# Access in code — use SDK, not gcloud in production
```

```python
# Python SDK — Workload Identity handles auth automatically on GCP
from google.cloud import secretmanager

client = secretmanager.SecretManagerServiceClient()
name = f"projects/{PROJECT_ID}/secrets/db-password/versions/latest"
response = client.access_secret_version(request={"name": name})
secret_value = response.payload.data.decode("UTF-8")
```

```typescript
// Node.js SDK
import { SecretManagerServiceClient } from "@google-cloud/secret-manager";

const client = new SecretManagerServiceClient();
const [version] = await client.accessSecretVersion({
  name: `projects/${PROJECT_ID}/secrets/db-password/versions/latest`,
});
const secretValue = version.payload!.data!.toString();
```

## Cloud SQL with Auth Proxy

```bash
# Run Auth Proxy sidecar (in Cloud Run, use Cloud SQL connector instead)
./cloud-sql-proxy MY_PROJECT:us-central1:myapp-db --port 5432
```

```python
# Python — Cloud SQL connector (preferred over proxy for Cloud Run)
from google.cloud.sql.connector import Connector
import sqlalchemy

connector = Connector()

def getconn():
    return connector.connect(
        "MY_PROJECT:us-central1:myapp-db",
        "pg8000",
        user="myapp-api-sa@MY_PROJECT.iam.gserviceaccount.com",
        enable_iam_auth=True,      # IAM database authentication
        db="myapp",
    )

engine = sqlalchemy.create_engine("postgresql+pg8000://", creator=getconn)
```

## Cloud Functions Gen 2

```typescript
// functions/processEvent.ts
import { onMessagePublished } from "firebase-functions/v2/pubsub";

export const processOrderEvent = onMessagePublished(
  {
    topic: "orders",
    region: "us-central1",
    serviceAccount: "myapp-func-sa@MY_PROJECT.iam.gserviceaccount.com",
    minInstances: 0,
  },
  async (event) => {
    const message = event.data.message.json;
    // process...
  },
);
```

## Workload Identity Federation (CI/CD — no JSON keys)

```yaml
# GitHub Actions
- name: Authenticate to GCP
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/123/locations/global/workloadIdentityPools/github/providers/github
    service_account: cicd-sa@MY_PROJECT.iam.gserviceaccount.com
```

```bash
# Terraform — create the WIF pool binding
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }
  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}
```

## IAM Least-Privilege Roles

| Workload | Role |
|---|---|
| Cloud Run reads Secret Manager | `roles/secretmanager.secretAccessor` |
| Cloud Run reads/writes GCS | `roles/storage.objectAdmin` (bucket-scoped) |
| Cloud Run connects to Cloud SQL | `roles/cloudsql.client` |
| Cloud Run publishes to Pub/Sub | `roles/pubsub.publisher` |
| CI/CD deploys Cloud Run | `roles/run.developer` + `roles/iam.serviceAccountUser` |

## Checklist

- [ ] Each Cloud Run service has a dedicated service account (not default Compute SA)
- [ ] `--no-allow-unauthenticated` set for internal services
- [ ] Secrets loaded via Secret Manager, not environment variables
- [ ] Cloud SQL connected via Auth Proxy or connector library — no public IP
- [ ] IAM roles granted at resource scope, not project scope
- [ ] Workload Identity Federation used in CI — no JSON key files
- [ ] Artifact Registry used for images — not Docker Hub
