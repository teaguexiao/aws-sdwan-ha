#!/bin/bash
#This is a script to failover between DX connection and SDWAN
#Make sure you have already create 2 routing tables and name the tags on the vCPE
#
#Author: Teague Xiao
#Modification Date: 2019-11-19
#
######################################
# Define the region
REGION=cn-north-1
#REGION=`aws ec2 describe-instances --query 'Reservations[*].{REGION:Instances[0].Placement.AvailabilityZone}' --output text | sed 's/.$//'| head -n 1`

# Define other variables by reading the tag info 
DXVIF_ID=`aws ec2 describe-tags --region $REGION --filters Name=key,Values=DXVIF_ID --query 'Tags[*].{ID:Value}' --output text`
RT_ID_DX=`aws ec2 describe-tags --region $REGION --filters Name=key,Values=RT_ID_DX --query 'Tags[*].{ID:Value}' --output text`
RT_ID_SDWAN=`aws ec2 describe-tags --region $REGION --filters Name=key,Values=RT_ID_SDWAN --query 'Tags[*].{ID:Value}' --output text`
SUBNET_ID=`aws ec2 describe-tags --region $REGION --filters Name=key,Values=SUBNET_ID --query 'Tags[*].{ID:Value}' --output text`

#Fixed Variable
RT_ASSOCIATE_ID=INIT
HA_STATUS=DX

echo `date` "-- Starting HA Monitor"

while [ . ]; do

  BGPSTATUS=`aws directconnect describe-virtual-interfaces --virtual-interface-id $DXVIF_ID --region $REGION --query 'virtualInterfaces[*].{STATUS:bgpPeers[0].bgpStatus}' --output text`
  if [ "$BGPSTATUS" == "up" ] && [ "$HA_STATUS" == "SDWAN" ]; then
  echo `date` "-- Direct Connect Back online, switching to DX"
  RT_ASSOCIATE_ID=`aws ec2 describe-route-tables --region cn-north-1 \
  --filters "Name= association.subnet-id,Values=$SUBNET_ID" \
  --query 'RouteTables[*].{RTBASSOID:Associations[0].RouteTableAssociationId}' \
  --output text`
  
  sleep 5
  #Replacing Route Table
  /usr/bin/aws ec2 replace-route-table-association --route-table-id $RT_ID_DX --association-id $RT_ASSOCIATE_ID --region $REGION
  
  HA_STATUS=DX
  continue
  fi
  
  if [ "$BGPSTATUS" == "down" ] && [ "$HA_STATUS" == "DX" ]; then
  echo `date` "-- Direct Connect failure, switching to SD-WAN"
  
  #Replacing Route Table
  RT_ASSOCIATE_ID=`aws ec2 describe-route-tables --region cn-north-1 \
  --filters "Name= association.subnet-id,Values=$SUBNET_ID" \
  --query 'RouteTables[*].{RTBASSOID:Associations[0].RouteTableAssociationId}' \
  --output text`

  sleep 5
  /usr/bin/aws ec2 replace-route-table-association --route-table-id $RT_ID_SDWAN --association-id $RT_ASSOCIATE_ID --region $REGION
  
  HA_STATUS=SDWAN
  
  fi
  
  echo `date` "-- Nothing goes wrong, keep monitoring"
  sleep 2
 
sleep 10
done
