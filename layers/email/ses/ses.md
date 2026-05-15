# Amazon SES Standards

## Install

```bash
# Node.js
npm install @aws-sdk/client-ses @aws-sdk/client-sesv2

# Python
pip install boto3
```

## Client setup

```typescript
// lib/ses.ts
import { SESv2Client, SendEmailCommand } from "@aws-sdk/client-sesv2";

export const sesClient = new SESv2Client({
  region: process.env.AWS_SES_REGION ?? "us-east-1",
});

export const FROM_ADDRESS = `"MyApp" <noreply@mail.myapp.com>`;
```

```python
# lib/ses.py
import boto3

ses = boto3.client("sesv2", region_name="us-east-1")
FROM_ADDRESS = '"MyApp" <noreply@mail.myapp.com>'
```

## Send a simple email (TypeScript)

```typescript
// lib/mailer.ts
import { SESv2Client, SendEmailCommand } from "@aws-sdk/client-sesv2";
import { sesClient, FROM_ADDRESS } from "./ses";
import logger from "./logger";

export interface SendEmailParams {
  to: string | string[];
  subject: string;
  html: string;
  text: string; // Always include plain-text fallback
  replyTo?: string;
}

export async function sendEmail(params: SendEmailParams): Promise<string> {
  const recipients = Array.isArray(params.to) ? params.to : [params.to];

  const command = new SendEmailCommand({
    FromEmailAddress: FROM_ADDRESS,
    Destination: { ToAddresses: recipients },
    ReplyToAddresses: [params.replyTo ?? "support@myapp.com"],
    Content: {
      Simple: {
        Subject: { Data: params.subject, Charset: "UTF-8" },
        Body: {
          Html: { Data: params.html, Charset: "UTF-8" },
          Text: { Data: params.text, Charset: "UTF-8" },
        },
      },
    },
  });

  const response = await sesClient.send(command);
  logger.info("email_sent", { messageId: response.MessageId, recipients: recipients.length });
  return response.MessageId!;
}
```

## SES templates

```typescript
// Create template (run once via CLI or CDK)
import { CreateEmailTemplateCommand } from "@aws-sdk/client-sesv2";

await sesClient.send(new CreateEmailTemplateCommand({
  TemplateName: "WelcomeEmail",
  TemplateContent: {
    Subject: "Welcome to MyApp, {{full_name}}!",
    Html: `
      <h1>Hi {{full_name}},</h1>
      <p>Thanks for joining MyApp. <a href="{{verification_url}}">Verify your email</a>.</p>
    `,
    Text: "Hi {{full_name}}, verify your email: {{verification_url}}",
  },
}));
```

```typescript
// Send using template
import { SendEmailCommand } from "@aws-sdk/client-sesv2";

export async function sendWelcomeEmail(params: {
  email: string;
  fullName: string;
  verificationUrl: string;
}): Promise<void> {
  const command = new SendEmailCommand({
    FromEmailAddress: FROM_ADDRESS,
    Destination: { ToAddresses: [params.email] },
    Content: {
      Template: {
        TemplateName: "WelcomeEmail",
        TemplateData: JSON.stringify({
          full_name: params.fullName,
          verification_url: params.verificationUrl,
        }),
      },
    },
  });

  await sesClient.send(command);
}
```

## Typed mailer service (Python)

```python
# lib/mailer.py
import json
import logging
from dataclasses import dataclass

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
ses = boto3.client("sesv2", region_name="us-east-1")
FROM_ADDRESS = '"MyApp" <noreply@mail.myapp.com>'


@dataclass
class EmailMessage:
    to: list[str]
    subject: str
    html: str
    text: str
    reply_to: str = "support@myapp.com"


def send_email(message: EmailMessage) -> str:
    try:
        response = ses.send_email(
            FromEmailAddress=FROM_ADDRESS,
            Destination={"ToAddresses": message.to},
            ReplyToAddresses=[message.reply_to],
            Content={
                "Simple": {
                    "Subject": {"Data": message.subject, "Charset": "UTF-8"},
                    "Body": {
                        "Html": {"Data": message.html, "Charset": "UTF-8"},
                        "Text": {"Data": message.text, "Charset": "UTF-8"},
                    },
                }
            },
        )
        message_id = response["MessageId"]
        logger.info("email_sent", extra={"message_id": message_id, "recipients": len(message.to)})
        return message_id
    except ClientError as exc:
        logger.exception("email_send_failed", extra={"error": exc.response["Error"]["Code"]})
        raise


def send_templated_email(
    to: list[str],
    template_name: str,
    template_data: dict,
) -> str:
    response = ses.send_email(
        FromEmailAddress=FROM_ADDRESS,
        Destination={"ToAddresses": to},
        Content={
            "Template": {
                "TemplateName": template_name,
                "TemplateData": json.dumps(template_data),
            }
        },
    )
    return response["MessageId"]
```

## Bounce and complaint handling (SNS → Lambda)

```typescript
// lambdas/ses-notifications/handler.ts
import { SNSEvent } from "aws-lambda";
import { db } from "@/lib/db"; // your DB client
import logger from "@/lib/logger";

interface SESNotification {
  notificationType: "Bounce" | "Complaint" | "Delivery";
  bounce?: {
    bounceType: "Permanent" | "Transient" | "Undetermined";
    bouncedRecipients: Array<{ emailAddress: string; action: string }>;
  };
  complaint?: {
    complainedRecipients: Array<{ emailAddress: string }>;
    complaintFeedbackType: string;
  };
}

export async function handler(event: SNSEvent): Promise<void> {
  for (const record of event.Records) {
    const message = JSON.parse(record.Sns.Message) as SESNotification;

    if (message.notificationType === "Bounce" && message.bounce) {
      const { bounceType, bouncedRecipients } = message.bounce;
      for (const recipient of bouncedRecipients) {
        if (bounceType === "Permanent") {
          // Hard bounce — never send to this address again
          await db.emailSuppression.upsert({
            where: { email: recipient.emailAddress },
            create: { email: recipient.emailAddress, reason: "hard_bounce", suppressedAt: new Date() },
            update: { reason: "hard_bounce", suppressedAt: new Date() },
          });
          logger.warn("hard_bounce_suppressed", { email: recipient.emailAddress });
        } else {
          // Soft bounce — track for retry logic
          logger.info("soft_bounce", { email: recipient.emailAddress });
        }
      }
    }

    if (message.notificationType === "Complaint" && message.complaint) {
      for (const recipient of message.complaint.complainedRecipients) {
        await db.emailSuppression.upsert({
          where: { email: recipient.emailAddress },
          create: {
            email: recipient.emailAddress,
            reason: "complaint",
            suppressedAt: new Date(),
          },
          update: { reason: "complaint", suppressedAt: new Date() },
        });
        logger.warn("complaint_suppressed", {
          email: recipient.emailAddress,
          feedbackType: message.complaint.complaintFeedbackType,
        });
      }
    }
  }
}
```

## CDK — SES configuration set + SNS feedback

```typescript
// lib/email-stack.ts
import * as cdk from "aws-cdk-lib";
import * as ses from "aws-cdk-lib/aws-ses";
import * as sns from "aws-cdk-lib/aws-sns";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as lambdaEventSources from "aws-cdk-lib/aws-lambda-event-sources";
import { Construct } from "constructs";

export class EmailStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const bounceTopic = new sns.Topic(this, "SESBounceTopic");
    const complaintTopic = new sns.Topic(this, "SESComplaintTopic");

    const configSet = new ses.ConfigurationSet(this, "ConfigSet", {
      configurationSetName: "myapp-config-set",
      suppressionReasons: [ses.SuppressionReasons.BOUNCES, ses.SuppressionReasons.COMPLAINTS],
    });

    new ses.CfnConfigurationSetEventDestination(this, "BounceDestination", {
      configurationSetName: configSet.configurationSetName!,
      eventDestination: {
        name: "BounceAndComplaint",
        enabled: true,
        matchingEventTypes: ["BOUNCE", "COMPLAINT"],
        snsDestination: { topicArn: bounceTopic.topicArn },
      },
    });

    const notificationHandler = new lambda.Function(this, "SESNotificationHandler", {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: "handler.handler",
      code: lambda.Code.fromAsset("lambdas/ses-notifications"),
    });

    notificationHandler.addEventSource(
      new lambdaEventSources.SnsEventSource(bounceTopic)
    );
    notificationHandler.addEventSource(
      new lambdaEventSources.SnsEventSource(complaintTopic)
    );

    // Verify domain identity
    new ses.EmailIdentity(this, "DomainIdentity", {
      identity: ses.Identity.domain("mail.myapp.com"),
      dkimSigning: true,
    });
  }
}
```

## DNS records for deliverability

```
# SPF
mail.myapp.com. TXT "v=spf1 include:amazonses.com ~all"

# DMARC
_dmarc.myapp.com. TXT "v=DMARC1; p=quarantine; pct=100; rua=mailto:dmarc-reports@myapp.com; ruf=mailto:dmarc-forensics@myapp.com; adkim=s; aspf=s"

# Custom MAIL FROM (set in SES console, adds MX + TXT)
mail.myapp.com. MX 10 feedback-smtp.us-east-1.amazonses.com.
mail.myapp.com. TXT "v=spf1 include:amazonses.com ~all"

# DKIM CNAME records (provided by SES after Easy DKIM setup)
xxxxxxxx._domainkey.myapp.com. CNAME xxxxxxxx.dkim.amazonses.com.
```

## Pre-send suppression check

```typescript
// Always check suppression list before sending
export async function isEmailSuppressed(email: string): Promise<boolean> {
  const suppression = await db.emailSuppression.findUnique({ where: { email } });
  return suppression !== null;
}

export async function safeSendEmail(params: SendEmailParams): Promise<string | null> {
  const to = Array.isArray(params.to) ? params.to : [params.to];
  const allowed = await Promise.all(
    to.map(async (email) => ({ email, suppressed: await isEmailSuppressed(email) }))
  );
  const recipients = allowed.filter((r) => !r.suppressed).map((r) => r.email);

  if (recipients.length === 0) {
    logger.warn("all_recipients_suppressed");
    return null;
  }

  return sendEmail({ ...params, to: recipients });
}
```

## Common mistakes

| Mistake | Fix |
|---|---|
| No SNS bounce/complaint handler | Set up SNS topics + Lambda handler on day 1; SES suspends accounts with high rates |
| Sending to unverified sandbox addresses | Verify test addresses in sandbox; request production access before launch |
| No plain-text body | Always include `text` body alongside `html` — required by email standards |
| Logging email body | Never log HTML/text content — may contain PII |
| No suppression list check | Check your suppression table before every send |
| MAIL FROM = default amazonses.com | Use custom MAIL FROM domain for SPF alignment |
| No DMARC record | Publish `p=quarantine` at minimum; `p=reject` after monitoring |
| Rate-limiting not handled | Catch `TooManyRequestsException` and back off with exponential retry |
