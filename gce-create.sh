#!/bin/bash

COUNT=$(gcloud compute instances list | grep host1 -c || true)
if [ $COUNT -gt 0 ]; then
   echo "Instance exists.. Deleting.."
   gcloud compute instances delete host1 --zone us-east1-b --quiet
fi

COUNT=$(gcloud compute instances list | grep host1 -c || true)
if [ $COUNT -gt 0 ]; then
   echo "Unable to remove instance"
   exit 1
fi

gcloud compute instances create host1 --zone=us-east1-b --machine-type=n1-standard-1 --image=mycentos7-new --image-project=citric-sprite-204213
