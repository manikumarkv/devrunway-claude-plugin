# AWS AppConfig Standards

## Configuration Profile Schema (Feature Flags)

```json
{
  "new-checkout-flow": {
    "enabled": false,
    "rolloutPercentage": 0
  },
  "ai-recommendations": {
    "enabled": true,
    "rolloutPercentage": 100
  },
  "dark-mode": {
    "enabled": true,
    "rolloutPercentage": 50
  }
}
```

## CDK Setup

```typescript
// infra/stacks/appconfig-stack.ts
import * as appconfig from "aws-cdk-lib/aws-appconfig";
import * as cdk from "aws-cdk-lib";

export class AppConfigStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props: cdk.StackProps & { stage: string }) {
    super(scope, id, props);

    const app = new appconfig.CfnApplication(this, "App", {
      name: `myapp-${props.stage}`,
    });

    const env = new appconfig.CfnEnvironment(this, "Env", {
      applicationId: app.ref,
      name: props.stage,
    });

    const profile = new appconfig.CfnConfigurationProfile(this, "FeatureFlags", {
      applicationId: app.ref,
      name: "feature-flags",
      locationUri: "hosted",
      type: "AWS.Freeform",
    });

    const hostedConfig = new appconfig.CfnHostedConfigurationVersion(this, "FlagsV1", {
      applicationId: app.ref,
      configurationProfileId: profile.ref,
      content: JSON.stringify({
        "new-checkout-flow": { enabled: false, rolloutPercentage: 0 },
        "ai-recommendations": { enabled: true, rolloutPercentage: 100 },
      }),
      contentType: "application/json",
    });

    // Instant deployment strategy for feature flags
    new appconfig.CfnDeployment(this, "Deployment", {
      applicationId: app.ref,
      environmentId: env.ref,
      configurationProfileId: profile.ref,
      configurationVersion: hostedConfig.ref,
      deploymentStrategyId: "AppConfig.AllAtOnce",
    });
  }
}
```

## Lambda Extension Setup

```typescript
// serverless.yml or CDK Lambda definition
// Add the extension layer for your region
// See: https://docs.aws.amazon.com/appconfig/latest/userguide/appconfig-integration-lambda-extensions.html
```

```typescript
// src/lib/featureFlags.ts — Lambda handler using extension
interface FeatureFlags {
  "new-checkout-flow": { enabled: boolean; rolloutPercentage: number };
  "ai-recommendations": { enabled: boolean; rolloutPercentage: number };
}

let cachedFlags: FeatureFlags | null = null;

async function fetchFlags(): Promise<FeatureFlags> {
  const appName = process.env.APPCONFIG_APP!;
  const envName = process.env.APPCONFIG_ENV!;
  const profileName = "feature-flags";

  // Extension serves from cache — no network overhead on every invocation
  const url = `http://localhost:2772/applications/${appName}/environments/${envName}/configurations/${profileName}`;

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`AppConfig fetch failed: ${response.status}`);
  }
  return response.json() as Promise<FeatureFlags>;
}

export async function getFlags(): Promise<FeatureFlags> {
  // Cache within a Lambda execution context (warm invocations)
  if (cachedFlags) return cachedFlags;

  try {
    cachedFlags = await fetchFlags();
    return cachedFlags;
  } catch (err) {
    console.warn("AppConfig unavailable — using safe defaults", { err });
    // Always define safe defaults (flags disabled)
    return {
      "new-checkout-flow": { enabled: false, rolloutPercentage: 0 },
      "ai-recommendations": { enabled: false, rolloutPercentage: 0 },
    };
  }
}

export function isFlagEnabled(
  flags: FeatureFlags,
  flagName: keyof FeatureFlags,
  userId?: string,
): boolean {
  const flag = flags[flagName];
  if (!flag.enabled) return false;
  if (flag.rolloutPercentage >= 100) return true;
  if (!userId) return false;

  // Deterministic bucketing by user ID
  const hash = [...userId].reduce((acc, c) => acc + c.charCodeAt(0), 0);
  return (hash % 100) < flag.rolloutPercentage;
}
```

## Lambda Handler Usage

```typescript
// src/handlers/checkout.ts
import { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { getFlags, isFlagEnabled } from "../lib/featureFlags";

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const flags = await getFlags();
  const userId = event.requestContext.authorizer?.lambda?.userId as string;

  if (isFlagEnabled(flags, "new-checkout-flow", userId)) {
    return newCheckoutHandler(event);
  }
  return legacyCheckoutHandler(event);
};
```

## Non-Lambda (Server / Long-Running Process)

```typescript
// src/lib/appConfigClient.ts
import { AppConfigDataClient, StartConfigurationSessionCommand, GetLatestConfigurationCommand } from "@aws-sdk/client-appconfigdata";

const client = new AppConfigDataClient({ region: process.env.AWS_REGION });

let sessionToken: string | undefined;
let cachedConfig: string = "{}";
let lastFetch = 0;
const CACHE_TTL_MS = 30_000; // 30 seconds

async function getConfig(): Promise<Record<string, unknown>> {
  const now = Date.now();
  if (now - lastFetch < CACHE_TTL_MS && cachedConfig) {
    return JSON.parse(cachedConfig);
  }

  if (!sessionToken) {
    const session = await client.send(new StartConfigurationSessionCommand({
      ApplicationIdentifier: process.env.APPCONFIG_APP!,
      EnvironmentIdentifier: process.env.APPCONFIG_ENV!,
      ConfigurationProfileIdentifier: "feature-flags",
      RequiredMinimumPollIntervalInSeconds: 30,
    }));
    sessionToken = session.InitialConfigurationToken;
  }

  const result = await client.send(new GetLatestConfigurationCommand({
    ConfigurationToken: sessionToken!,
  }));

  sessionToken = result.NextPollConfigurationToken;
  lastFetch = now;

  if (result.Configuration && result.Configuration.length > 0) {
    cachedConfig = Buffer.from(result.Configuration).toString("utf-8");
  }

  return JSON.parse(cachedConfig);
}
```

## Deployment Strategy Recommendations

| Use Case | Strategy |
|---|---|
| Feature flags | `AppConfig.AllAtOnce` |
| App config (low risk) | `AppConfig.Linear20PercentEvery6Minutes` |
| App config (high risk) | `AppConfig.Canary10Percent20Minutes` |
| Database connection settings | Custom with validator Lambda |

## Validator Lambda

```typescript
// Validates that new config is valid JSON before deployment
export const handler = async (event: {
  content: string;
  configurationProfile: { type: string };
}) => {
  const content = Buffer.from(event.content, "base64").toString("utf-8");
  const flags = JSON.parse(content);

  // Validate required structure
  const required = ["new-checkout-flow", "ai-recommendations"];
  for (const key of required) {
    if (!(key in flags)) throw new Error(`Missing required flag: ${key}`);
    if (typeof flags[key].enabled !== "boolean") throw new Error(`${key}.enabled must be boolean`);
  }
};
```

## Checklist

- [ ] AppConfig Application and Environment match service and stage
- [ ] Feature flag JSON schema committed to source control
- [ ] Lambda extension layer ARN added for the correct region
- [ ] Safe defaults defined for all flags (disabled state)
- [ ] Non-Lambda services cache config with 30s TTL
- [ ] Validator Lambda attached to production configuration profile
- [ ] Rollout percentage used for gradual flag enablement

## Common mistakes

| Mistake | Fix |
|---|---|
| Calling the AppConfig API on every Lambda invocation | Use the Lambda extension (localhost:2772) or an in-process cache; direct API calls add latency and incur charges |
| Not attaching a validator Lambda to the configuration profile | Without a validator, malformed JSON deploys to production and breaks the app; attach a validator that checks schema on every deployment |
| Using `AppConfig.AllAtOnce` strategy for high-risk config changes | Use `AppConfig.Canary10Percent20Minutes` or a linear strategy with a rollback alarm for anything touching database or auth config |
| Storing the full config in environment variables | Env vars are static at Lambda startup; use AppConfig so config updates take effect without a redeploy |
| Not defining safe defaults when the AppConfig fetch fails | Network errors happen; always return a disabled-flag default object from `catch` blocks so the app stays functional |
| Using the deprecated `GetConfiguration` API | Use the newer `StartConfigurationSession` + `GetLatestConfiguration` (`@aws-sdk/client-appconfigdata`) — the old API is throttled per invocation |
| Missing `RequiredMinimumPollIntervalInSeconds` on sessions | Setting this below 15 seconds triggers throttling; 30 seconds is the recommended minimum for non-Lambda workloads |
