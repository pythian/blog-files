#Documentation: https://cloud.google.com/sdk/gcloud/reference/logging/read
gcloud logging read 'resource.type="http_load_balancer" AND jsonPayload.previewSecurityPolicy.outcome="DENY"' --format=json  --limit=1