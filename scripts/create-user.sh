#!/bin/bash

# Wait for SSM agent to register the instance
echo "Waiting for SSM agent on instance $INSTANCE_ID..."
for i in $(seq 1 30); do
  STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query "InstanceInformationList[0].PingStatus" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null)

  if [ "$STATUS" = "Online" ]; then
    echo "SSM agent is online."
    break
  fi
  echo "Waiting for SSM agent... attempt $i"
  sleep 10
done

if [ "$STATUS" != "Online" ]; then
  echo "ERROR: SSM agent not online after 5 minutes"
  exit 1
fi

# Wait for helper script to be available (installed by user_data)
echo "Waiting for helper script on instance..."
for i in $(seq 1 30); do
  COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["test -x /usr/local/bin/create-headscale-user.sh && echo READY || echo NOTREADY"]' \
    --query "Command.CommandId" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null)

  sleep 5

  OUTPUT=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "StandardOutputContent" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null)

  if [ "$(echo "$OUTPUT" | tr -d '[:space:]')" = "READY" ]; then
    echo "Helper script is ready."
    break
  fi
  echo "Waiting for helper script... attempt $i"
  sleep 10
done

# Run the helper script on the EC2 - simple command, no quoting issues
echo "Creating user $USERNAME..."
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"/usr/local/bin/create-headscale-user.sh $USERNAME\"]" \
  --query "Command.CommandId" \
  --output text \
  --region "$AWS_REGION")

# Wait for completion
for i in $(seq 1 30); do
  sleep 5
  CMD_STATUS=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "Status" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null)
  echo "  Status: $CMD_STATUS"
  if [ "$CMD_STATUS" = "Success" ] || [ "$CMD_STATUS" = "Failed" ]; then
    break
  fi
done

if [ "$CMD_STATUS" = "Failed" ]; then
  ERROR=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "StandardErrorContent" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null)
  echo "ERROR: User creation failed: $ERROR"
  exit 1
fi

# Get auth key from command output
AUTH_KEY=$(aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --query "StandardOutputContent" \
  --output text \
  --region "$AWS_REGION" 2>/dev/null | tr -d '[:space:]')

if [ -z "$AUTH_KEY" ]; then
  echo "ERROR: Failed to get auth key for $USERNAME"
  exit 1
fi

echo "Got auth key for $USERNAME"

# Store auth key in SSM Parameter Store
aws ssm put-parameter \
  --name "/headscale/users/${USERNAME}/authkey" \
  --value "$AUTH_KEY" \
  --type "SecureString" \
  --overwrite \
  --region "$AWS_REGION"

echo "Auth key stored in SSM: /headscale/users/${USERNAME}/authkey"
