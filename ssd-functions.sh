#!/bin/bash

send_ssd_webhook() {
  echo "SSD Functions script triggered"
  echo "Sending build event to SSD..."
  curl --location "$SSD_URL/webhook/v1/ssd" \
    --header 'Content-Type: application/json' \
    --header "X-OpsMx-Auth: $SSD_TOKEN" \
    --data "{
      \"jobname\": \"${JOB_NAME}\",
      \"buildnumber\": \"${BUILD_NUMBER}\",
      \"joburl\": \"${JOB_URL}\",
      \"builduser\": \"ssdadmin@opsmx.io\",
      \"giturl\": \"${GIT_URL}\",
      \"gitbranch\": \"${BRANCH_NAME}\",
      \"artifacts\": [
        { \"image\": \"$IMAGENAME\" }
      ]
    }"
  sleep 10s
}

trigger_data_collection() {
  echo "Triggering Data Collection API..."
  local WEBHOOK_URL="$SSD_URL/webhook/api/v1/datacollection"
  local AUTH_TOKEN="WjndNWJNncsn0394ujnoi4kas"
  local MAX_RETRIES=100
  local RETRY_DELAY=10
  local retry_count=0

  local PAYLOAD=$(cat <<EOF
{
  "artifactName": "${NAME}",
  "artifactTag": "${TAG}",
  "organizationName": "opsmx"
}
EOF
)

  while true; do
    echo "Attempt $((retry_count + 1)) to send webhook..."

    RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/webhook_response.txt \
      -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -H "X-OpsMx-Auth: $AUTH_TOKEN" \
      -d "$PAYLOAD")

    BODY=$(cat /tmp/webhook_response.txt)

    if [ "$RESPONSE" -eq 200 ]; then
      echo "Webhook sent successfully!"
      echo "Response: $BODY"
      break
    elif [ "$RESPONSE" -eq 500 ]; then
      echo "Webhook failed with HTTP 500."
      echo "Response: $BODY"
      exit 1
    else
      echo "Webhook failed with status $RESPONSE. Retrying..."
      echo "Response: $BODY"
      retry_count=$((retry_count + 1))
      if [ "$retry_count" -ge "$MAX_RETRIES" ]; then
        echo "Max retries reached. Exiting..."
        exit 1
      fi
      sleep "$RETRY_DELAY"
    fi
  done
}

send_firewall_request() {
  echo "Sending Firewall Access Check..."
  local FIREWALL_URL="$SSD_URL/ssdservice/v1/ssdFirewall"
  local TEAM_NAME="default"
  local APP_NAME="ssd-check"
  local ACCOUNT="dev"
  local CLUSTER="ssd-int"

  local FIREWALL_PAYLOAD=$(cat <<EOF
{
  "teamName": "${TEAM_NAME}",
  "appName": "${APP_NAME}",
  "account": "${ACCOUNT}",
  "clusterName": "${CLUSTER}",
  "image": "${IMAGENAME}"
}
EOF
)

  FIREWALL_RESPONSE=$(curl -s -X POST "$FIREWALL_URL" \
    -H "Content-Type: application/json" \
    -H "X-OpsMx-Auth: $SSD_TOKEN" \
    -d "$FIREWALL_PAYLOAD")

  echo "Firewall response: $FIREWALL_RESPONSE"

  if echo "$FIREWALL_RESPONSE" | grep -q '"allow":true'; then
    echo "Access allowed."
  else
    echo "Access denied."
    exit 1
  fi

  echo "SSD Functions script execution is completed"
}
