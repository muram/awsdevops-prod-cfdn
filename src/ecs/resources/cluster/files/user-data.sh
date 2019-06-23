Content-Type: multipart/mixed
boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
Content-Type: text/x-shellscript
charset="us-ascii"
#!/bin/bash -xe

# runs the CloudFormation::Init
/opt/aws/bin/cfn-init -v --stack ${AWS::StackName} --resource ContainerInstancesLC --region ${AWS::Region}

# join ecs cluster
echo ECS_CLUSTER=${ECSCluster} >>/etc/ecs/ecs.config

# install cfn-bootstrap and run cfn-signal to determine success or failure of new launched instances
/opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackName} --resource ECSAutoScalingGroup --region ${AWS::Region}

# Install AWS SSM agent RPM for later mass commands
# Not present by default on ECS Optimized AMI:
# https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-manual-agent-install.html#agent-install-al

# For x86_64 instances, so what you're probably using
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

# For arm64 instances, you'd run this:
# yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_arm64/amazon-ssm-agent.rpm

# For 32-bit:
# yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_386/amazon-ssm-agent.rpm

--==BOUNDARY==
Content-Type: text/x-shellscript
charset="us-ascii"
#!/usr/bin/env bash
# Write the awslogs bootstrap script to /usr/local/bin/bootstrap-awslogs.sh
cat >/usr/local/bin/bootstrap-awslogs.sh <<-'EOF'
	#!/usr/bin/env bash
	exec 2>>/var/log/ecs/cloudwatch-logs-start.log
	set -x
	
	until curl -s http://localhost:51678/v1/metadata
	do
		sleep 1
	done
	
	# Set the region to send CloudWatch Logs data to (the region where the container instance is located)
	cp /etc/awslogs/awscli.conf /etc/awslogs/awscli.conf.bak
	region=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
	sed -i -e "s/region = .*/region = $region/g" /etc/awslogs/awscli.conf
	
	# Grab the cluster and container instance ARN from instance metadata
	cluster=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .Cluster')
	container_instance_id=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .ContainerInstanceArn' | awk -F/ '{print $2}' )
	
	# Replace the cluster name and container instance ID placeholders with the actual values
	cp /etc/awslogs/awslogs.conf /etc/awslogs/awslogs.conf.bak
	sed -i -e "s/{cluster}/$cluster/g" /etc/awslogs/awslogs.conf
	sed -i -e "s/{container_instance_id}/$container_instance_id/g" /etc/awslogs/awslogs.conf
EOF

--==BOUNDARY==
Content-Type: text/x-shellscript
charset="us-ascii"
#!/usr/bin/env bash
# Write the bootstrap-awslogs systemd unit file to /etc/systemd/system/bootstrap-awslogs.service
cat >/etc/systemd/system/bootstrap-awslogs.service <<-EOF
	[Unit]
	Description=Bootstrap awslogs agent
	Requires=ecs.service
	After=ecs.service
	Before=awslogsd.service
	
	[Service]
	Type=oneshot
	RemainAfterExit=yes
	ExecStart=/usr/local/bin/bootstrap-awslogs.sh
	
	[Install]
	WantedBy=awslogsd.service
EOF

--==BOUNDARY==
Content-Type: text/x-shellscript
charset="us-ascii"
#!/bin/sh

# Start logs
chmod +x /usr/local/bin/bootstrap-awslogs.sh
systemctl daemon-reload
systemctl enable bootstrap-awslogs.service
systemctl enable awslogsd.service
systemctl start awslogsd.service --no-block

# Start SSM
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

--==BOUNDARY==--
