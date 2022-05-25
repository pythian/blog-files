# create the service
# use the hello world container
# allow unauthenticated users
gcloud run deploy cloudarmoursample \
    --image us-docker.pkg.dev/cloudrun/container/hello:latest \
    --allow-unauthenticated \
    --ingress=all \
    --max-instances=2 \
    --region=us-east1 

cloudservice=$(gcloud run services list --limit=1)
cloudservice=$(cut -d ' ' -f 7 <<< $cloudservice)
cloudservice=$(cut -c 9- <<< $cloudservice)
echo $cloudservice

gcloud compute network-endpoint-groups create serverless-neg-crs \
    --global \
    --network-endpoint-type=internet-fqdn-port  

gcloud compute network-endpoint-groups update serverless-neg-crs \
    --global \
    --add-endpoint='fqdn='$(echo $cloudservice | xargs )',port=443'


gcloud compute backend-services create backend-service-crs \
    --load-balancing-scheme=EXTERNAL \
    --protocol=HTTPS \
    --global

gcloud compute backend-services update backend-service-crs \
    --global \
    --enable-logging \
    --custom-request-header='HOST:'$(echo $cloudservice | xargs )

gcloud compute backend-services add-backend backend-service-crs \
    --global \
    --network-endpoint-group=serverless-neg-crs \
    --global-network-endpoint-group


 gcloud compute url-maps create url-map-crs \
    --default-service=backend-service-crs \
    --global  


gcloud compute target-http-proxies create target-http-proxy-crs \
    --url-map=url-map-crs \
    --global

gcloud compute forwarding-rules create http-forwarding-rule-crs \
    --load-balancing-scheme=EXTERNAL \
    --target-http-proxy=target-http-proxy-crs \
    --global \
    --ports=80
echo "****************************************************************"
echo "****SEE IP BELOW for CURL commands in 10-curl-test.bash file****"
echo "****************************************************************"
gcloud compute forwarding-rules list
echo "****************************************************************"
echo "****SEE IP ABOVE for CURL commands in 10-curl-test.bash file****"
echo "****************************************************************"





