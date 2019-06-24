#!/usr/bin/env bash

# Install aws-cfn-bootstrap
yum install -y aws-cfn-bootstrap

# runs the CloudFormation::Init
/opt/aws/bin/cfn-init -v --stack ${AWS::StackName} --resource ContainerInstancesLC --region ${AWS::Region}

# cluster to join REPLACE `YOURCLUSTERNAMEHERE` OBVIOUSLY
echo ECS_CLUSTER=${ECSCluster} >>/etc/ecs/ecs.config

# Install AWS SSM agent RPM for later mass commands
# Not present by default on ECS Optimized AMI:
# https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-manual-agent-install.html#agent-install-al

# For x86_64 instances, so what you're probably using
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

# For arm64 instances, you'd run this:
# yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_arm64/amazon-ssm-agent.rpm

# For 32-bit:
# yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_386/amazon-ssm-agent.rpm

# Start SSM
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
