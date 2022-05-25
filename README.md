# cloudarmorsample

The files in src assume you already have:
* google cloud project setup and set as default
* gcloud CLI installed - https://cloud.google.com/sdk/docs/install

Otherwise run scripts:
* 01-create-cloud-run.bash
* 03-create-cloud-armor-preview.bash
*
* WAIT for up to 15 minutes
*
* 10-curl-tests.bash (once you receive an HTML success edit as appropriate)
* 11-logging-retrieve-cmds.bash (run as approriate between scripts 10, 03, 04, 05)
*
* scripts 04 and 05 will normally be applyed in under 5 minutes.
* 
* When all complete run 99-destroy-cloud-run.bash to remove all items.