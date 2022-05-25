# create the service
# use the hello world container
# allow unauthenticated users
gcloud run services delete cloudarmoursample --region=us-east1 --quiet

#gcloud compute instances delete test-vm-crs --zone=us-east1-b --quiet
#gcloud compute instances delete vm-client-crs --zone=us-east1-b --quiet

gcloud compute forwarding-rules delete http-forwarding-rule-crs --global --quiet

gcloud compute target-http-proxies delete target-http-proxy-crs --global --quiet

gcloud compute url-maps delete url-map-crs --global --quiet

#gcloud compute backend-services remove-backend backend-service-crs --region=us-east1 --network-endpoint-group=serverless-neg-crs --quiet

gcloud compute backend-services delete backend-service-crs --global --quiet

gcloud compute network-endpoint-groups delete serverless-neg-crs --global --quiet

#gcloud compute networks subnets delete proxy-only-subnet-crs --region=us-east1 --quiet

#gcloud compute networks subnets delete lb-subnet-crs --region=us-east1 --quiet

#gcloud compute firewall-rules delete fw-allow-ssh-crs --quiet

#gcloud compute networks delete lb-network-crs --quiet

gcloud compute security-policies delete security-policy-crs --quiet

