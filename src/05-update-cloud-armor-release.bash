
gcloud compute security-policies rules delete 1000 \
    --security-policy security-policy-crs \
    --quiet

gcloud compute security-policies rules create 1000 \
    --security-policy security-policy-crs \
    --expression "evaluatePreconfiguredExpr('xss-stable',  \
        ['owasp-crs-v030001-id941320-xss' \
        ])" \
    --action "deny-403" \
    --description "XSS attack filtering" 




