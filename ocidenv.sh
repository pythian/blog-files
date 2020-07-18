i#!/bin/bash -l 
############################################################################################
#Script Name	: ocidenv.sh                                                                                             
#Description	: Generates a ocidtab file      
#Args           : ocidenv.sh <config_file_path> <oci_profile> <compartment_name> <vcn_name>                                                                                          
#Author       	: Abhilash Kumar Bhattaram
#Email         	: abhilash8@gmail.com     
############################################################################################
PROFILE_FILE=${1}
PROFILE_NAME=${2}
COMP_NAME=${3}
VCN_NAME=${4}

## Function to Generate OCID
gen_ocidtab() 
{
	export COMP_OCID=$(oci iam compartment list --query "data[?\"name\"=='$COMP_NAME'].{id:id}" --profile $PROFILE_NAME | jq -r '.[]."id"')
	export VCN_OCID=$(oci network vcn list -c $COMP_OCID --query "data[?\"display-name\"=='$VCN_NAME'].{id:id}" --all --profile $PROFILE_NAME | jq -r '.[]."id"')
	export AVD_OCID_1=$(oci iam availability-domain list -c $COMP_OCID --query "data[?contains(\"name\",'-AD-1')].{name:name}" --profile $PROFILE_NAME | jq -r '.[]."name"')
	export AVD_OCID_2=$(oci iam availability-domain list -c $TENANCY_OCID --query "data[?contains(\"name\",'-AD-2')].{name:name}" --profile $PROFILE_NAME | jq -r '.[]."name"')
	export AVD_OCID_3=$(oci iam availability-domain list -c $TENANCY_OCID --query "data[?contains(\"name\",'-AD-3')].{name:name}" --profile $PROFILE_NAME | jq -r '.[]."name"')
	###
	# Place holder to generate all other OCID Vaiables	
	###	
	echo "TENANCY_OCID="$TENANCY_OCID > ~/.${PROFILE_NAME}-ocidtab
	echo "VCN_OCID="$VCN_OCID >> ~/.${PROFILE_NAME}-ocidtab
	echo "COMP_OCID="$COMP_OCID >> ~/.${PROFILE_NAME}-ocidtab
	echo "CONFIG_PROFILE="$PROFILE_NAME >> ~/.${PROFILE_NAME}-ocidtab
	echo "HOME_REGION="$PROFILE_REGION >> ~/.${PROFILE_NAME}-ocidtab
	echo "TARGET_REGION="$PROFILE_REGION >> ~/.${PROFILE_NAME}-ocidtab	# Defaults to Home Region 
	echo "AVD_OCID_1="$AVD_OCID_1 >> ~/.${PROFILE_NAME}-ocidtab
	echo "AVD_OCID_2="$AVD_OCID_2 >> ~/.${PROFILE_NAME}-ocidtab
	echo "AVD_OCID_3="$AVD_OCID_3 >> ~/.${PROFILE_NAME}-ocidtab
	###
	# Place holder to populate all other OCID Vaiables to ocidtab file  
	###
	chmod +x .${PROFILE_NAME}-ocidtab 	
	#cat ~/.${PROFILE_NAME}-ocidtab| column -t -s "="
}

## Main
if [ -z "$4" ]
then
	echo "Usage is ocidenv.sh <config_file_path> <oci_profile> <compartment_name> <vcn_name>"
else
	# Source Tenancy and Region Details from config File
	t=$(grep $PROFILE_FILE -A 5 -e"$PROFILE_NAME" | grep tenancy)
	TENANCY_OCID=$(echo $t | awk -v srch="tenancy=" -v repl="" '{ sub(srch,repl,$0); print $1 }')
	pr=$(grep $PROFILE_FILE -A 5 -e"$PROFILE_NAME" | grep region)
	PROFILE_REGION=$(echo $pr | awk -v srch="region=" -v repl="" '{ sub(srch,repl,$0); print $1 }')
	# Invoke ocid generation
	gen_ocidtab
fi
