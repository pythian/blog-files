
gcloud compute security-policies create security-policy-crs \
    --description "Cloud Run Policy"

gcloud compute backend-services update backend-service-crs \
    --security-policy security-policy-crs \
    --global


gcloud compute security-policies rules create 1000 \
    --security-policy security-policy-crs \
    --expression "evaluatePreconfiguredExpr('xss-stable')" \
    --action "deny-403" \
    --description "XSS attack filtering" \
    --preview


