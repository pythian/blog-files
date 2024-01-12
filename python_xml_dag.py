import xml.etree.ElementTree as ET
from xml.dom import minidom
from google.cloud import storage
from google.cloud import bigquery
import datetime
from datetime import timedelta
import pendulum
import logging
import time
import os
from airflow import models
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.transfers.gcs_to_sftp import GCSToSFTPOperator
from airflow.hooks.base_hook import BaseHook
from airflow.operators.dummy_operator import DummyOperator
from airflow.sensors.external_task import ExternalTaskSensor
from airflow.providers.google.cloud.operators.datafusion import CloudDataFusionStartPipelineOperator




# set timezone for DAG schedule
local_tz = pendulum.timezone("America/New_York")


default_args = {
   'start_date': datetime.datetime(2022, 12, 1, 7, tzinfo = local_tz),
   'retries': 0,
}


#pipeline specific variables
current_day_folder = datetime.datetime.today().strftime('%Y-%m-%d')
filename = 'Product_'+ datetime.datetime.today().strftime('%Y%m%d%H%M%S') + '.xml'
sftp_<connection_name> = BaseHook.get_connection('sftp_<connection_name>')


# load environment variables
datafusion_instance_location = os.environ.get("DATAFUSION_INSTANCE_LOCATION")
datafusion_instance_name = os.environ.get("DATAFUSION_INSTANCE_NAME")
project_id = os.environ.get("GCP_PROJECT_PIPE")
project_name = os.environ.get("GCP_PROJECT_DATA")
gcs_extracts_bucket = os.environ.get("GCS_BUCKET_EXTRACTS")
data_project_id = os.environ.get("GCP_PROJECT_DATA")
commerce_hub_folder_path="/<tgt_folder_path>/{}".format(current_day_folder) if project_id=="<dev-pipe>" or project_id=="<stg-pipe>" else "<tgt_folder_path>"




#set pipeline_timeout for Data Fusion Pipelines
#pipeline will only wait for these many seconds for its completion. Modify this value accordingly.
pipeline_timeout=3600




def generate_xml():
   logger = logging.getLogger("generate_xml")
   root = ET.Element('DemandStreamFeed')  # Root element
   client = bigquery.Client()
   query = (f"SELECT * FROM `{data_project_id}.<table_name>`")
   query_job = client.query(query)  # Make an API request.


  
   for rows in  query_job:
       Product  = ET.SubElement(root, 'Product')
       descInfo_child = ET.SubElement(Product, 'DescriptiveInformation')
       if  rows['DescriptiveInformation_Feature1']:
           child = ET.SubElement(descInfo_child, 'Feature1')
           child.text = rows['DescriptiveInformation_Feature1']
       if rows['DescriptiveInformation_Feature2'] :
           child = ET.SubElement(descInfo_child, 'Feature2')
           child.text = rows['DescriptiveInformation_Feature2']
       if rows['DescriptiveInformation_Feature3'] :
           child = ET.SubElement(descInfo_child, 'Feature3')
           child.text = rows['DescriptiveInformation_Feature3']
       if rows['DescriptiveInformation_Feature4'] :
           child = ET.SubElement(descInfo_child, 'Feature4')
           child.text = rows['DescriptiveInformation_Feature4']
       if rows['DescriptiveInformation_Feature5'] :
           child = ET.SubElement(descInfo_child, 'Feature5')
           child.text = rows['DescriptiveInformation_Feature5']
       if  ['DescriptiveInformation_SearchTerm1'] :                  
           child = ET.SubElement(descInfo_child, 'SearchTerm1')
           child.text = rows['DescriptiveInformation_SearchTerm1']
       if  rows['DescriptiveInformation_SearchTerm2'] :
           child = ET.SubElement(descInfo_child, 'SearchTerm2')
           child.text = rows['DescriptiveInformation_SearchTerm2']
       if rows['DescriptiveInformation_SearchTerm3'] :
           child = ET.SubElement(descInfo_child, 'SearchTerm3')
           child.text = rows['DescriptiveInformation_SearchTerm3']
       if rows['DescriptiveInformation_SearchTerm4'] :
           child = ET.SubElement(descInfo_child, 'SearchTerm4')
           child.text = rows['DescriptiveInformation_SearchTerm4']
       if rows['DescriptiveInformation_SearchTerm5'] :
           child = ET.SubElement(descInfo_child, 'SearchTerm5')
           child.text = rows['DescriptiveInformation_SearchTerm5']


       child = ET.SubElement(descInfo_child, 'ColorFamily')
       child.text = rows['DescriptiveInformation_ColorFamily']
       child = ET.SubElement(descInfo_child, 'Color')
       child.text = rows['DescriptiveInformation_Color']
       child = ET.SubElement(descInfo_child, 'Size')
       child.text = rows['DescriptiveInformation_Size']
       child = ET.SubElement(descInfo_child, 'PackageQuantity')
       child.text = str(rows['DescriptiveInformation_PackageQuantity'])
       child = ET.SubElement(descInfo_child, 'IsAdultProduct')
       child.text = rows['DescriptiveInformation_IsAdultProduct']
       child = ET.SubElement(descInfo_child, 'Condition')
       child.text = rows['DescriptiveInformation_Condition']
       if rows['DescriptiveInformation_Pattern'] :
           child = ET.SubElement(descInfo_child, 'Pattern')
           child.text  = rows['DescriptiveInformation_Pattern']
       child = ET.SubElement(descInfo_child, 'Prop65')
       child.text = rows['DescriptiveInformation_Prop65']
       child = ET.SubElement(descInfo_child, 'Description')
       child.text = rows['DescriptiveInformation_Description']
       child = ET.SubElement(descInfo_child, 'FullHTMLDescription')
       child.text = rows['DescriptiveInformation_FullHTMLDescription']
       child = ET.SubElement(descInfo_child, 'CountryProducedIn')
       child.text = rows['DescriptiveInformation_CountryProducedIn']       
              
       basic_product = ET.SubElement(Product, 'BasicProductIdentifiers')
       child = ET.SubElement(basic_product, 'SKU')
       child.text = str(rows['BasicProductIdentifiers_SKU'])       
       child = ET.SubElement(basic_product, 'ProductID')
       child.text = str(rows['BasicProductIdentifiers_ProductID'])
       child = ET.SubElement(basic_product, 'Brand')
       child.text = rows['BasicProductIdentifiers_Brand']
       child = ET.SubElement(basic_product, 'Manufacturer')
       child.text = rows['BasicProductIdentifiers_Manufacturer']
              
       child = ET.SubElement(basic_product, 'GTIN')
       child.text = rows['BasicProductIdentifiers_GTIN']
       child = ET.SubElement(basic_product, 'MfrPartNumber')
       child.text = rows['BasicProductIdentifiers_MfrPartNumber']
       child = ET.SubElement(basic_product, 'ProductType')
       child.text = rows['BasicProductIdentifiers_ProductType']
       child = ET.SubElement(basic_product, 'Title')
       child.text = str(rows['BasicProductIdentifiers_Title'])
       child = ET.SubElement(basic_product, 'ProductURL')
       child.text = str(rows['BasicProductIdentifiers_ProductURL'])
       child = ET.SubElement(basic_product, 'MerchantCategory')
       child.text = rows['BasicProductIdentifiers_MerchantCategory']
              
       product_relationship = ET.SubElement(Product, 'ProductRelationships')
       child = ET.SubElement(product_relationship, 'FamilySKU')
       child.text = rows['ProductRelationships_FamilySKU']
       child = ET.SubElement(product_relationship, 'VariesByFieldName')
       child.text = rows['ProductRelationships_VariesByFieldNames']
       pricingInfo = ET.SubElement(Product, 'PricingInformation')
       child = ET.SubElement(pricingInfo, 'ItemCOGS')
       child.text = str(rows['PricingInformation_ItemCOGS'])
       child = ET.SubElement(pricingInfo, 'StandardPrice')
       child.text = str(rows['PricingInformation_StandardPrice'])
       child = ET.SubElement(pricingInfo, 'SalePrice')
       child.text = str(rows['PricingInformation_SalePrice'])
       availabilityInfo = ET.SubElement(Product, 'AvailabilityInformation')
       child = ET.SubElement(availabilityInfo, 'AvailabilityCode')
       child.text = str(rows['AvailabilityInformation_AvailabilityCode'])
       child = ET.SubElement(availabilityInfo, 'Quantity')
       child.text = str(rows['AvailabilityInformation_Quantity'])
       child = ET.SubElement(availabilityInfo, 'FulfillmentLatency')
       child.text = str(rows['AvailabilityInformation_FulfillmentLatency'])
       imageInfo = ET.SubElement(Product, 'ImageInformation')
       child = ET.SubElement(imageInfo, 'ImageLocationSwatch')            
       child.text = rows['ImageInformation_ImageLocationSwatch']           
       child = ET.SubElement(imageInfo, 'ImageLocationMain')
       child.text =  rows['ImageInformation_ImageLocationMain']          
       child = ET.SubElement(imageInfo, 'ImageLocationAlternate1')
       child.text = rows['ImageInformation_ImageLocationAlternate1']
       child = ET.SubElement(imageInfo, 'ImageLocationAlternate2')
       child.text = rows['ImageInformation_ImageLocationAlternate2']
       child = ET.SubElement(imageInfo, 'ImageLocationAlternate3')
       child.text = rows['ImageInformation_ImageLocationAlternate3']
       child = ET.SubElement(imageInfo, 'ImageLocationAlternate4')
       child.text = rows['ImageInformation_ImageLocationAlternate4']
       child = ET.SubElement(imageInfo, 'ImageLocationAlternate5')
       child.text = rows['ImageInformation_ImageLocationAlternate5']
       child = ET.SubElement(imageInfo, 'ImageLocationAlternate6')
       child.text = rows['ImageInformation_ImageLocationAlternate6']
       child = ET.SubElement(imageInfo, 'ImageLocationAlternate7')
       child.text = rows['ImageInformation_ImageLocationAlternate7']
       child = ET.SubElement(imageInfo, 'ImageLocationAlternate8')
       child.text = rows['ImageInformation_ImageLocationAlternate8']
               
       shippingInfo = ET.SubElement(Product, 'ShippingInformation')
       child = ET.SubElement(shippingInfo, 'PackageLengthUnit')
       child.text = rows['ShippingInformation_PackageLengthUnit']
       child = ET.SubElement(shippingInfo, 'PackageLength')
       child.text = rows['ShippingInformation_PackageLength']
       child = ET.SubElement(shippingInfo, 'PackageWidth')
       child.text = rows['ShippingInformation_PackageWidth']
       child = ET.SubElement(shippingInfo, 'PackageHeight')
       child.text = rows['ShippingInformation_PackageHeight']
       child = ET.SubElement(shippingInfo, 'PackageWeightUnit')
       child.text = rows['ShippingInformation_PackageWeightUnit']
       child = ET.SubElement(shippingInfo, 'PackageWeight')
       child.text = rows['ShippingInformation_PackageWeight']
       child = ET.SubElement(shippingInfo, 'ShippingStandard')
       child.text = rows['ShippingInformation_ShippingStandard']
       child = ET.SubElement(shippingInfo, 'Shipping2Day')
       child.text = rows['ShippingInformation_Shipping2Day']
       child = ET.SubElement(shippingInfo, 'ShippingOvernight')
       child.text = rows['ShippingInformation_ShippingOvernight']   
       child = ET.SubElement(shippingInfo, 'CountryOfOrigin')
       child.text = rows['ShippingInformation_CountryOfOrigin'] 


   xmlstr = minidom.parseString(ET.tostring(root, encoding='utf-8', method='xml')).toprettyxml(indent="  ")  
   logger.info("XML file:{} generated successfully".format(filename))      
   write_to_gs(xmlstr)


def write_to_gs(xmlstr):
   logger = logging.getLogger("write_to_gs")
   storage_client = storage.Client(project=project_name)
   bucket = storage_client.get_bucket(gcs_extracts_bucket)
   blob = bucket.blob('<blob_file_path>'+ '/{}/'.format(datetime.datetime.today().strftime('%Y-%m-%d'))+filename)
   blob.upload_from_string(xmlstr)


   logger.info("file:{} uploaded to bucket: {} successfully".format(filename, bucket.name))




with models.DAG(
       dag_id="send_commerce_hub_feed",
       schedule_interval="30 7 * * *",
       description="DAG to generate and send commerce hub feed",
       max_active_runs=1,
       default_args=default_args,
       catchup=False) as dag:




       t_start = DummyOperator(task_id="start")    


       commerce_hub_xml_generator = PythonOperator(task_id='<task_id>',
                                      python_callable=generate_xml,
                                      op_kwargs={},
                                      provide_context=True,
                                      dag=dag)


       send_commerce_hub_xml = GCSToSFTPOperator(
       task_id="<>",
       sftp_conn_id=sftp_commerce_hub,
       source_bucket=gcs_extracts_bucket,
       source_object="salesforce/commerce_hub/xml/{}/".format(current_day_folder) + "*",
       destination_path=commerce_hub_folder_path,
       keep_directory_structure=False
       )


       t_end = DummyOperator(task_id="end")


       t_start >> <pipeline_1> >> t_load_sfcc_commerce_hub
      
       t_start >> <pipeline_2> >> t_load_sfcc_commerce_hub


       t_start >> <pipeline_3> >> t_load_sfcc_commerce_hub
      
       t_load_sfcc_commerce_hub >> commerce_hub_xml_generator  >>  send_commerce_hub_xml >> t_end
