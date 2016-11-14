#!/bin/bash
## Set all s3 buckets in account to log to specific bucket
## You must be logged previously via ANWBIS
## version 1.0 - November 2016
## @author = pablo.vera @ explotacion BEEVA
## BEE Automated

PROFILE="$1-$2-admin"
TARGET=""

if [ "$#" -ne 4 ]; then
  echo " "
  echo "###########################################################"
  echo "##  The purpose of this script is to enable S3 logs      ##"
  echo "##  to a certain S3 target bucket, specified as argument ##"
  echo "###########################################################"
  echo "Usage: $0 PROJECT ENVIRONMENT TARGET-EU-BUCKET TARGET-US-BUCKET" >&2
  echo " "
  exit 1
fi

aws s3 ls --profile $PROFILE | awk '{print $3}' > buckets.txt

#enable write & read-acp permissions to target buckets

#EU
#aws s3api create-bucket --profile $PROFILE --bucket $3 --region eu-west-1
aws s3api put-bucket-acl --profile $PROFILE --bucket $3 --grant-write URI=http://acs.amazonaws.com/groups/s3/LogDelivery --grant-read-acp URI=http://acs.amazonaws.com/groups/s3/LogDelivery

#US
#aws s3api create-bucket --profile $PROFILE --bucket $4 --region us-east-1
aws s3api put-bucket-acl --profile $PROFILE --bucket $4 --grant-write URI=http://acs.amazonaws.com/groups/s3/LogDelivery --grant-read-acp URI=http://acs.amazonaws.com/groups/s3/LogDelivery

while read p; do
#   set the target bucket in the logging json depending on the location of each bucket
#   the NULL evaluation is due to AWS region US Standard that replies with null to this call
#   it's been null since 2006 although it's something to take in consideration for future changes
	location=`aws s3api get-bucket-location --profile $PROFILE --bucket $p | jq -r ".LocationConstraint"`
	if [ "$location" == "EU" ] || [ "$location" == "eu-west-1" ]; then
		#enable logging to bucket at "Ireland"
		TARGET=$3
	elif [ "$location" == "null" ]; then
		#enable logging to bucket at "Virginia"
                TARGET=$4
	fi

#change the prefix of the logs in the bucket with each origin bucket
jq --arg bucket $TARGET --arg tag "logs/$p" '.LoggingEnabled.TargetPrefix = $tag | .LoggingEnabled.TargetBucket = $bucket' logging.json > this.json

sleep 2
#and finally applies the configuration to the bucket, we are all done
aws s3api put-bucket-logging --profile $PROFILE --bucket $p --bucket-logging-status file://this.json

done < buckets.txt
