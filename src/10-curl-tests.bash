
#TEST_URL=http://34.111.57.70/
TEST_URL='http://'$1'/'

if [ -z "$1" ]
then
    echo Please pass ip/dns as parameter
    exit 1
else
    echo $TEST_URL"api/myendpoint"
fi

#curl -H "HOST:cloudarmoursample-6flqhec6ba-ue.a.run.app"  https://run.app

#is the load balancer ready?
curl $TEST_URL

#will pass rule 1000
#curl -X POST -H "Content-Type: application/json" --data '{"companyname": "pythian", "address": "123 main st"}' $TEST_URL"api/myendpoint"

#should fail rule 1000 initial
#curl -X POST -H "Content-Type: application/json" --data '{"companyname": "pythian<body>", "address": "123 main st"}' $TEST_URL"api/myendpoint"

#should fail rule 1000 final
#curl -X POST -H "Content-Type: application/json" --data '{"companyname": "pythian<script>", "address": "123 main st"}' $TEST_URL"api/myendpoint"
