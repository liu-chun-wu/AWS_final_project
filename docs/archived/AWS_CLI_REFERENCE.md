# AWS CLI Commands Reference Guide

**Purpose:** Comprehensive reference for all AWS CLI commands used in the Flask CI/CD pipeline
**Scope:** EC2, CloudFormation, ECR, CloudWatch, IAM, and SAM CLI operations
**Use Cases:** Testing, deployment, monitoring, and troubleshooting

---

## Table of Contents

1. [EC2 (Elastic Compute Cloud) Commands](#1-ec2-elastic-compute-cloud-commands)
2. [CloudFormation Commands](#2-cloudformation-commands)
3. [ECR (Elastic Container Registry) Commands](#3-ecr-elastic-container-registry-commands)
4. [CloudWatch Logs Commands](#4-cloudwatch-logs-commands)
5. [IAM Commands](#5-iam-identity-and-access-management-commands)
6. [STS Commands](#6-sts-security-token-service-commands)
7. [CloudWatch Metrics Commands](#7-cloudwatch-metrics-commands)
8. [SAM CLI Commands](#8-sam-cli-commands)
9. [Common Patterns and Flags](#9-common-parameter-patterns-and-flags)
10. [Command Cheat Sheets](#10-command-cheat-sheet-by-use-case)

---

## 1. EC2 (Elastic Compute Cloud) Commands

### 1.1 EC2 Instance Management

#### Describe Instances (Query Instance Details)

```bash
# Get all instance information for a specific instance ID
aws ec2 describe-instances \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0 \
    --query 'Reservations[0].Instances[0]'

# Get only instance state
aws ec2 describe-instances \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0 \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text

# Get public IP address
aws ec2 describe-instances \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0 \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text

# Get private IP address
aws ec2 describe-instances \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0 \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text

# Find instances by tag name
aws ec2 describe-instances \
    --region us-east-1 \
    --filters "Name=tag:Name,Values=jenkins-ci-cd-demo" \
              "Name=instance-state-name,Values=running,pending,stopped,stopping" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text

# Get instance type and launch time
aws ec2 describe-instances \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0 \
    --query 'Reservations[0].Instances[0].[InstanceType,LaunchTime]' \
    --output text
```

**What it does:** Retrieves detailed information about EC2 instances including state, IP addresses, tags, and configuration.

**Common use cases:**
- Check if Jenkins instance is running
- Get current public IP after starting stopped instance
- Verify instance exists before performing operations
- Monitor instance state transitions

**Key flags:**
- `--instance-ids`: Specific instance ID(s) to query
- `--filters`: Filter by tags, state, or other attributes
- `--query`: JMESPath expression to extract specific fields
- `--output text|json|table`: Format output

---

#### Start Instances

```bash
# Start a stopped EC2 instance
aws ec2 start-instances \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0 \
    --output text

# Wait for instance to reach running state
aws ec2 wait instance-running \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0
```

**What it does:** Starts a stopped EC2 instance and optionally waits until it's fully running.

**Common use cases:**
- Resume Jenkins CI/CD server after stopping for cost savings
- Restart development environments
- Wake up on-demand testing infrastructure

**Important notes:**
- Public IP address changes when instance restarts (unless using Elastic IP)
- GitHub webhooks must be updated with new IP after restart
- Instance typically takes 30-60 seconds to become accessible

---

#### Stop Instances

```bash
# Stop a running EC2 instance
aws ec2 stop-instances \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0 \
    --output text

# Wait for instance to reach stopped state
aws ec2 wait instance-stopped \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0
```

**What it does:** Gracefully stops a running EC2 instance (equivalent to shutdown).

**Common use cases:**
- Save costs when Jenkins is not needed (stops EC2 charges)
- End of work day in development environments
- AWS Learner Lab session ends

**Cost implications:**
- Stopped instances: $0/hour for compute (only EBS storage charges ~$2/month)
- Running t2.small: ~$0.023/hour (~$17/month if 24/7)

---

#### Terminate Instances

```bash
# Terminate (delete) an EC2 instance
aws ec2 terminate-instances \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0

# Wait for termination to complete
aws ec2 wait instance-terminated \
    --region us-east-1 \
    --instance-ids i-1234567890abcdef0
```

**What it does:** Permanently deletes an EC2 instance.

**Common use cases:**
- Complete cleanup of demo/test environments
- Remove unused infrastructure
- Free up AWS Learner Lab resources

**Important warnings:**
- Irreversible operation
- Instance data is lost (unless EBS volumes have `DeleteOnTermination=false`)
- Associated Elastic IPs are released

---

#### Launch Instances

```bash
# Launch new EC2 instance with full configuration
aws ec2 run-instances \
    --region us-east-1 \
    --image-id ami-0c55b159cbfafe1f0 \
    --instance-type t2.small \
    --key-name vockey \
    --security-group-ids sg-0123456789abcdef0 \
    --iam-instance-profile Arn=arn:aws:iam::123456789012:instance-profile/LabInstanceProfile \
    --user-data file:///tmp/jenkins-userdata.sh \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=jenkins-ci-cd-demo},{Key=Environment,Value=demo},{Key=Purpose,Value=Jenkins-CI-CD}]' \
    --query 'Instances[0].InstanceId' \
    --output text
```

**What it does:** Creates and launches a new EC2 instance with specified configuration.

**Common use cases:**
- Initial Jenkins server provisioning
- Creating dedicated CI/CD infrastructure
- Launching test environments

**Key parameters:**
- `--image-id`: AMI ID (Amazon Linux 2023 recommended)
- `--instance-type`: Size/capacity (t2.small for Jenkins)
- `--key-name`: SSH key pair name (vockey for AWS Learner Lab)
- `--security-group-ids`: Firewall rules
- `--iam-instance-profile`: AWS permissions for the instance
- `--user-data`: Initialization script (runs on first boot)
- `--block-device-mappings`: EBS volume configuration
- `--tag-specifications`: Resource tags for organization

---

### 1.2 EC2 Security Groups

#### Describe Security Groups

```bash
# Get security group by name
aws ec2 describe-security-groups \
    --region us-east-1 \
    --filters "Name=group-name,Values=jenkins-ec2-sg-demo" \
    --query 'SecurityGroups[0].GroupId' \
    --output text

# View security group rules
aws ec2 describe-security-groups \
    --region us-east-1 \
    --group-ids sg-0123456789abcdef0

# List all security groups
aws ec2 describe-security-groups \
    --region us-east-1 \
    --query 'SecurityGroups[*].[GroupName,GroupId,Description]' \
    --output table
```

**What it does:** Retrieves security group configuration and firewall rules.

**Common use cases:**
- Verify security group exists before creating instance
- Check if correct ports are open (22, 8080, 443)
- Troubleshoot connectivity issues
- Audit security configurations

---

#### Create Security Group

```bash
# Create new security group
aws ec2 create-security-group \
    --region us-east-1 \
    --group-name jenkins-ec2-sg-demo \
    --description "Security group for Jenkins CI/CD server (demo)" \
    --vpc-id vpc-0123456789abcdef0 \
    --query 'GroupId' \
    --output text
```

**What it does:** Creates a new security group (firewall) in specified VPC.

**Common use cases:**
- Initial Jenkins infrastructure setup
- Creating isolated network security zones

---

#### Authorize Security Group Ingress (Add Inbound Rules)

```bash
# Allow SSH (port 22)
aws ec2 authorize-security-group-ingress \
    --region us-east-1 \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

# Allow Jenkins web interface (port 8080)
aws ec2 authorize-security-group-ingress \
    --region us-east-1 \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0

# Allow HTTPS (port 443)
aws ec2 authorize-security-group-ingress \
    --region us-east-1 \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Allow port range
aws ec2 authorize-security-group-ingress \
    --region us-east-1 \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp \
    --port 8000-9000 \
    --cidr 0.0.0.0/0
```

**What it does:** Adds inbound firewall rules to allow traffic on specific ports.

**Common use cases:**
- Enable SSH access for administration
- Open Jenkins port 8080 for web interface and GitHub webhooks
- Allow HTTPS for secure communications

**Security note:** `0.0.0.0/0` allows access from any IP. In production, restrict to specific IP ranges.

---

### 1.3 EC2 Key Pairs

#### Describe Key Pairs

```bash
# Check if key pair exists
aws ec2 describe-key-pairs \
    --key-names vockey \
    --region us-east-1

# List all available key pairs
aws ec2 describe-key-pairs \
    --region us-east-1 \
    --query 'KeyPairs[*].KeyName' \
    --output table

# Get key pair fingerprint
aws ec2 describe-key-pairs \
    --key-names vockey \
    --region us-east-1 \
    --query 'KeyPairs[0].KeyFingerprint' \
    --output text
```

**What it does:** Verifies SSH key pairs exist in AWS account.

**Common use cases:**
- Validate SSH key before launching instance
- List available keys for region
- Troubleshoot SSH connection issues

---

### 1.4 EC2 Images (AMIs)

#### Describe Images

```bash
# Find latest Amazon Linux 2023 AMI
aws ec2 describe-images \
    --region us-east-1 \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023.*-x86_64" \
              "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text

# Get AMI details
aws ec2 describe-images \
    --region us-east-1 \
    --image-ids ami-0c55b159cbfafe1f0 \
    --query 'Images[0].[Name,ImageId,CreationDate,Architecture]' \
    --output table

# Find Ubuntu 22.04 AMI
aws ec2 describe-images \
    --region us-east-1 \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04*" \
              "Name=architecture,Values=x86_64" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text
```

**What it does:** Searches for Amazon Machine Images (AMIs) matching criteria.

**Common use cases:**
- Get latest Amazon Linux 2023 AMI for EC2 launch
- Find specific OS versions
- Verify AMI availability in region

---

### 1.5 VPC (Virtual Private Cloud)

#### Describe VPCs

```bash
# Get default VPC ID
aws ec2 describe-vpcs \
    --region us-east-1 \
    --filters "Name=isDefault,Values=true" \
    --query 'Vpcs[0].VpcId' \
    --output text

# List all VPCs
aws ec2 describe-vpcs \
    --region us-east-1 \
    --query 'Vpcs[*].[VpcId,CidrBlock,IsDefault]' \
    --output table
```

**What it does:** Retrieves VPC information, typically to get default VPC for security group creation.

**Common use cases:**
- Get default VPC for launching instances
- Verify network configuration

---

## 2. CloudFormation Commands

### 2.1 Stack Management

#### Describe Stacks

```bash
# Get all stack information
aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1

# Get specific output value (API URL)
aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoApi`].OutputValue' \
    --output text

# Get Lambda function ARN output
aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoFunction`].OutputValue' \
    --output text

# Check stack status
aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'Stacks[0].StackStatus' \
    --output text

# Get all outputs in table format
aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'Stacks[0].Outputs' \
    --output table

# List all stacks
aws cloudformation list-stacks \
    --region us-east-1 \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query 'StackSummaries[*].[StackName,StackStatus,CreationTime]' \
    --output table
```

**What it does:** Retrieves CloudFormation stack details including outputs, status, and resources.

**Common use cases:**
- Get API Gateway URL after deployment
- Retrieve Lambda function ARN for logging
- Check deployment status
- Extract stack outputs for testing

**Stack statuses:**
- `CREATE_COMPLETE`: Stack created successfully
- `UPDATE_COMPLETE`: Stack updated successfully
- `CREATE_IN_PROGRESS`: Stack being created
- `UPDATE_IN_PROGRESS`: Stack being updated
- `ROLLBACK_COMPLETE`: Creation failed, rolled back
- `DELETE_COMPLETE`: Stack deleted
- `DELETE_IN_PROGRESS`: Stack being deleted

---

### 2.2 Stack Events and Monitoring

#### Describe Stack Events

```bash
# Get recent stack events (deployment progress)
aws cloudformation describe-stack-events \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --max-items 20 \
    --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
    --output table

# Get latest event
aws cloudformation describe-stack-events \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'StackEvents[0]' \
    --output json

# Filter events by resource status
aws cloudformation describe-stack-events \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' \
    --output table
```

**What it does:** Shows chronological events during stack creation/update/deletion.

**Common use cases:**
- Monitor deployment progress
- Troubleshoot deployment failures
- Understand what resources were created/updated
- Debug rollback reasons

**Event statuses:**
- `CREATE_IN_PROGRESS`: Resource being created
- `CREATE_COMPLETE`: Resource created successfully
- `CREATE_FAILED`: Resource creation failed
- `UPDATE_IN_PROGRESS`: Resource being updated
- `UPDATE_COMPLETE`: Resource updated successfully
- `DELETE_IN_PROGRESS`: Resource being deleted
- `DELETE_COMPLETE`: Resource deleted successfully

---

### 2.3 Stack Resources

#### List Stack Resources

```bash
# List all resources in stack
aws cloudformation list-stack-resources \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'StackResourceSummaries[*].[LogicalResourceId,ResourceType,ResourceStatus]' \
    --output table

# Get specific resource physical ID
aws cloudformation describe-stack-resource \
    --stack-name flask-demo-backend \
    --logical-resource-id FlaskDemoFunction \
    --region us-east-1 \
    --query 'StackResourceDetail.PhysicalResourceId' \
    --output text

# Filter resources by type
aws cloudformation list-stack-resources \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'StackResourceSummaries[?ResourceType==`AWS::Lambda::Function`]' \
    --output table
```

**What it does:** Lists all AWS resources managed by the CloudFormation stack.

**Common use cases:**
- Identify deployed Lambda functions
- Find API Gateway REST API IDs
- Track resource creation status
- Map logical to physical resource IDs

---

### 2.4 Stack Deletion

#### Delete Stack

```bash
# Delete entire CloudFormation stack
aws cloudformation delete-stack \
    --stack-name flask-demo-backend \
    --region us-east-1

# Wait for stack deletion to complete
aws cloudformation wait stack-delete-complete \
    --stack-name flask-demo-backend \
    --region us-east-1
```

**What it does:** Deletes CloudFormation stack and all managed resources.

**Common use cases:**
- Clean up demo/test deployments
- Remove failed deployments
- Free up resources to avoid AWS Learner Lab quotas

**Important warnings:**
- Deletes Lambda function, API Gateway, CloudWatch logs
- Irreversible operation
- Does NOT delete ECR images (must delete separately)

---

## 3. ECR (Elastic Container Registry) Commands

### 3.1 Repository Management

#### Describe Repositories

```bash
# Check if repository exists and get URI
aws ecr describe-repositories \
    --repository-names aws-lab-flask-demo \
    --region us-east-1 \
    --query 'repositories[0].repositoryUri' \
    --output text

# List all repositories
aws ecr describe-repositories \
    --region us-east-1 \
    --query 'repositories[*].[repositoryName,repositoryUri]' \
    --output table

# Get repository creation date
aws ecr describe-repositories \
    --repository-names aws-lab-flask-demo \
    --region us-east-1 \
    --query 'repositories[0].createdAt' \
    --output text
```

**What it does:** Retrieves information about ECR repositories.

**Common use cases:**
- Get ECR repository URI for Docker push
- Verify repository exists before CI build
- List all container repositories in account

---

#### Create Repository

```bash
# Create new ECR repository with image scanning enabled
aws ecr create-repository \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --image-scanning-configuration scanOnPush=true \
    --query 'repository.repositoryUri' \
    --output text

# Create with lifecycle policy
aws ecr create-repository \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256
```

**What it does:** Creates a new private container registry repository.

**Common use cases:**
- Initial infrastructure setup
- Create repository for new microservice
- Enable automatic vulnerability scanning

**Key flags:**
- `--image-scanning-configuration scanOnPush=true`: Automatically scan images for vulnerabilities when pushed
- `--encryption-configuration`: Enable encryption at rest

---

#### Delete Repository

```bash
# Delete repository (must be empty unless using --force)
aws ecr delete-repository \
    --repository-name aws-lab-flask-demo \
    --region us-east-1

# Force delete repository with images
aws ecr delete-repository \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --force
```

**What it does:** Deletes an ECR repository.

**Common use cases:**
- Complete cleanup of project resources
- Remove unused repositories

**Warning:** `--force` deletes all images in the repository

---

### 3.2 Image Management

#### Describe Images

```bash
# Get latest image tag and push time
aws ecr describe-images \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' \
    --output text

# Get push timestamp for specific tag
aws ecr describe-images \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --image-ids imageTag=manual-test \
    --query 'imageDetails[0].imagePushedAt' \
    --output text

# List recent 5 images with details
aws ecr describe-images \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --query 'sort_by(imageDetails,&imagePushedAt)[-5:].{Tag:imageTags[0],Pushed:imagePushedAt,Size:imageSizeInBytes}' \
    --output table

# Get image digest for specific tag
aws ecr describe-images \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --image-ids imageTag=latest \
    --query 'imageDetails[0].imageDigest' \
    --output text
```

**What it does:** Retrieves information about Docker images stored in ECR.

**Common use cases:**
- Auto-detect latest image for deployment
- Verify image was pushed successfully
- List available image versions
- Check image metadata and size

---

#### List Images

```bash
# Count images in repository
aws ecr list-images \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --query 'length(imageIds)' \
    --output text

# List all image tags
aws ecr list-images \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --query 'imageIds[*].imageTag' \
    --output table

# Filter images by tag pattern
aws ecr list-images \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --filter "tagStatus=TAGGED"
```

**What it does:** Lists all images in a repository (lighter query than describe-images).

**Common use cases:**
- Quick check if repository has any images
- Count total images
- List image tags without full metadata

---

#### Batch Delete Images

```bash
# Delete specific image by tag
aws ecr batch-delete-image \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --image-ids imageTag=old-version

# Delete multiple images
aws ecr batch-delete-image \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --image-ids imageTag=v1.0 imageTag=v1.1 imageTag=v1.2

# Delete untagged images
aws ecr list-images \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --filter "tagStatus=UNTAGGED" \
    --query 'imageIds[*]' \
    --output json | \
aws ecr batch-delete-image \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --image-ids file:///dev/stdin
```

**What it does:** Deletes one or more images from ECR repository.

**Common use cases:**
- Clean up old/unused images
- Free up storage space
- Remove test images

---

### 3.3 Authentication

#### Get Login Password

```bash
# Login to ECR for Docker push/pull
aws ecr get-login-password \
    --region us-east-1 | \
    docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# Alternative: get ECR registry from account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
```

**What it does:** Generates temporary authentication token for Docker to access ECR.

**Common use cases:**
- Before docker push to ECR
- Before docker pull from ECR
- CI/CD pipeline authentication

**Important notes:**
- Token expires after 12 hours
- Username is always "AWS"
- Password is piped from AWS CLI to Docker

---

## 4. CloudWatch Logs Commands

### 4.1 Log Groups

#### Describe Log Groups

```bash
# List all log groups
aws logs describe-log-groups \
    --region us-east-1 \
    --query 'logGroups[*].[logGroupName,storedBytes]' \
    --output table

# Find Lambda log groups
aws logs describe-log-groups \
    --region us-east-1 \
    --log-group-name-prefix /aws/lambda/ \
    --query 'logGroups[*].logGroupName' \
    --output table
```

**What it does:** Lists CloudWatch log groups.

**Common use cases:**
- Find Lambda function log group names
- Check log storage usage
- Verify logs are being created

---

#### Describe Log Streams

```bash
# Get most recent log stream
aws logs describe-log-streams \
    --log-group-name /aws/lambda/flask-demo-backend-FlaskDemoFunction-ABCD1234 \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --region us-east-1 \
    --query 'logStreams[0].logStreamName' \
    --output text

# List recent log streams
aws logs describe-log-streams \
    --log-group-name /aws/lambda/flask-demo-backend-FlaskDemoFunction-ABCD1234 \
    --order-by LastEventTime \
    --descending \
    --max-items 10 \
    --region us-east-1 \
    --query 'logStreams[*].[logStreamName,lastEventTime]' \
    --output table
```

**What it does:** Lists log streams within a CloudWatch log group.

**Common use cases:**
- Find latest Lambda execution log stream
- Identify active log streams
- Check if logs are being generated

---

### 4.2 Log Retrieval

#### Tail Logs

```bash
# Tail Lambda function logs (most recent)
aws logs tail /aws/lambda/flask-demo-backend-FlaskDemoFunction-ABCD1234 \
    --region us-east-1 \
    --follow

# Tail logs since specific time
aws logs tail /aws/lambda/flask-demo-backend-FlaskDemoFunction-ABCD1234 \
    --since 5m \
    --format short \
    --region us-east-1

# Tail logs with filter pattern
aws logs tail /aws/lambda/flask-demo-backend-FlaskDemoFunction-ABCD1234 \
    --since 10m \
    --filter-pattern "ERROR" \
    --region us-east-1

# Get last 10 log entries
aws logs tail /aws/lambda/flask-demo-backend-FlaskDemoFunction-ABCD1234 \
    --since 5m \
    --format short \
    --region us-east-1 | head -10
```

**What it does:** Displays recent CloudWatch log entries, optionally following new entries in real-time.

**Common use cases:**
- Monitor Lambda function execution
- Debug API errors
- Verify deployment endpoints being called
- Watch live traffic during testing

**Key flags:**
- `--follow`: Continuously stream new log entries (like tail -f)
- `--since 5m|1h|1d`: Show logs from last N minutes/hours/days
- `--format short|detailed|json`: Output format
- `--filter-pattern`: Filter logs by pattern (e.g., "ERROR", "status=500")

---

#### Filter Log Events

```bash
# Search logs for specific pattern
aws logs filter-log-events \
    --log-group-name /aws/lambda/flask-demo-backend-FlaskDemoFunction-ABCD1234 \
    --region us-east-1 \
    --filter-pattern "ERROR" \
    --max-items 50

# Search logs in time range
aws logs filter-log-events \
    --log-group-name /aws/lambda/flask-demo-backend-FlaskDemoFunction-ABCD1234 \
    --region us-east-1 \
    --start-time 1700000000000 \
    --end-time 1700001000000
```

**What it does:** Searches CloudWatch logs using filter patterns.

**Common use cases:**
- Find error messages
- Search for specific request IDs
- Filter logs by time range

---

## 5. IAM (Identity and Access Management) Commands

### 5.1 Roles

#### Get Role

```bash
# Verify LabRole exists (AWS Learner Lab)
aws iam get-role \
    --role-name LabRole \
    --query 'Role.Arn' \
    --output text

# Get role details
aws iam get-role \
    --role-name LabRole

# Get role trust policy
aws iam get-role \
    --role-name LabRole \
    --query 'Role.AssumeRolePolicyDocument'
```

**What it does:** Retrieves IAM role details including ARN and permissions policies.

**Common use cases:**
- Verify LabRole exists before deployment (required for AWS Learner Lab)
- Get role ARN for Lambda function configuration
- Check role trust policies

---

#### List Roles

```bash
# List all IAM roles
aws iam list-roles \
    --query 'Roles[*].[RoleName,Arn]' \
    --output table

# Find roles containing specific text
aws iam list-roles \
    --query 'Roles[?contains(RoleName, `Lab`)].RoleName' \
    --output table
```

**What it does:** Lists all IAM roles in the account.

**Common use cases:**
- Discover available roles
- Find Lab-related roles in AWS Learner Lab

---

### 5.2 Instance Profiles

#### List Instance Profiles

```bash
# Find LabInstanceProfile for EC2
aws iam list-instance-profiles \
    --query "InstanceProfiles[?contains(InstanceProfileName, 'LabInstanceProfile')].Arn | [0]" \
    --output text

# List all instance profiles
aws iam list-instance-profiles \
    --query 'InstanceProfiles[*].[InstanceProfileName,Arn]' \
    --output table
```

**What it does:** Lists IAM instance profiles that can be attached to EC2 instances.

**Common use cases:**
- Find LabInstanceProfile for Jenkins EC2 instance
- Grant EC2 instance AWS API access
- Enable EC2 to assume IAM role permissions

---

## 6. STS (Security Token Service) Commands

### 6.1 Account Information

#### Get Caller Identity

```bash
# Get current AWS account ID
aws sts get-caller-identity \
    --query 'Account' \
    --output text

# Get full caller identity (account, user, ARN)
aws sts get-caller-identity

# Get user/role ARN
aws sts get-caller-identity \
    --query 'Arn' \
    --output text

# Store account ID in variable
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $AWS_ACCOUNT_ID"
```

**What it does:** Returns details about the AWS account/user making the API call.

**Common use cases:**
- Verify AWS credentials are configured
- Get account ID for ECR URI construction
- Validate credentials haven't expired (common in AWS Learner Lab)
- Troubleshoot permission issues

**Output fields:**
- `Account`: 12-digit AWS account ID
- `UserId`: Unique identifier for IAM user/role
- `Arn`: Full ARN of the calling identity

---

## 7. CloudWatch Metrics Commands

### 7.1 EC2 Metrics

#### Get Metric Statistics

```bash
# Get average CPU utilization for past hour
aws cloudwatch get-metric-statistics \
    --region us-east-1 \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
    --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 3600 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text

# Get max CPU in last 24 hours
aws cloudwatch get-metric-statistics \
    --region us-east-1 \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
    --start-time "$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 3600 \
    --statistics Maximum
```

**What it does:** Retrieves CloudWatch metric data for monitoring and analysis.

**Common use cases:**
- Monitor Jenkins EC2 CPU usage
- Track Lambda invocation counts
- Analyze API Gateway request rates
- Check system resource utilization

**Key parameters:**
- `--namespace`: Service namespace (AWS/EC2, AWS/Lambda, AWS/ApiGateway)
- `--metric-name`: Specific metric (CPUUtilization, Invocations, Count)
- `--dimensions`: Resource identifier
- `--period`: Aggregation period in seconds (60, 300, 3600, 86400)
- `--statistics`: Average, Sum, Maximum, Minimum, SampleCount

---

### 7.2 Lambda Metrics

```bash
# Get Lambda invocation count
aws cloudwatch get-metric-statistics \
    --region us-east-1 \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=flask-demo-backend-FlaskDemoFunction-ABCD \
    --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 300 \
    --statistics Sum

# Get Lambda error count
aws cloudwatch get-metric-statistics \
    --region us-east-1 \
    --namespace AWS/Lambda \
    --metric-name Errors \
    --dimensions Name=FunctionName,Value=flask-demo-backend-FlaskDemoFunction-ABCD \
    --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 300 \
    --statistics Sum
```

**What it does:** Retrieves Lambda-specific CloudWatch metrics.

**Common use cases:**
- Monitor Lambda invocations
- Track error rates
- Measure function duration
- Analyze throttling events

---

## 8. SAM CLI Commands

### 8.1 SAM Validation and Build

```bash
# Validate SAM template syntax
sam validate --template aws/template.yaml

# Validate with specific config
sam validate \
    --template aws/template.yaml \
    --config-file aws/samconfig-demo.toml

# Build SAM application
sam build --template aws/template.yaml

# Build with containers (for compiled languages)
sam build \
    --use-container \
    --template aws/template.yaml

# Build specific function
sam build FlaskDemoFunction \
    --template aws/template.yaml
```

**What it does:** Validates SAM template syntax and builds application artifacts.

**Common use cases:**
- Verify template syntax before deployment
- Prepare Lambda deployment package
- Build containers for Lambda

**Key flags:**
- `--template`: Path to SAM template file
- `--use-container`: Build inside Docker container (matches Lambda environment)
- `--config-file`: Use specific configuration file

---

### 8.2 SAM Deployment

```bash
# Deploy with configuration file
sam deploy \
    --config-file aws/samconfig-demo.toml \
    --stack-name flask-demo-backend \
    --parameter-overrides ImageTag=manual-test \
    --resolve-image-repos \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset \
    --region us-east-1

# Interactive guided deployment
sam deploy --guided

# Deploy with capabilities
sam deploy \
    --template-file aws/.aws-sam/build/template.yaml \
    --stack-name flask-demo-backend \
    --capabilities CAPABILITY_IAM \
    --region us-east-1

# Deploy with tags
sam deploy \
    --config-file aws/samconfig-demo.toml \
    --tags Environment=demo Project=flask-ci-cd
```

**What it does:** Deploys serverless applications using AWS SAM (wraps CloudFormation).

**Common use cases:**
- Deploy Lambda functions from container images
- Create API Gateway with Lambda integration
- Update existing Lambda deployments with new images
- Manage infrastructure as code

**Key flags:**
- `--config-file`: Use saved deployment configuration
- `--parameter-overrides`: Pass parameters to template (e.g., ImageTag=latest)
- `--resolve-image-repos`: Auto-resolve ECR repository URIs
- `--no-confirm-changeset`: Skip changeset approval (for automation)
- `--no-fail-on-empty-changeset`: Exit successfully if no changes
- `--capabilities CAPABILITY_IAM`: Allow SAM to create IAM roles

---

### 8.3 SAM Local Testing

```bash
# Start local API Gateway
sam local start-api \
    --template aws/template.yaml \
    --port 3000

# Invoke function locally
sam local invoke FlaskDemoFunction \
    --template aws/template.yaml \
    --event events/test-event.json

# Generate sample event
sam local generate-event apigateway aws-proxy > events/test-event.json
```

**What it does:** Run serverless applications locally for testing.

**Common use cases:**
- Test Lambda functions locally before deployment
- Debug API Gateway integrations
- Generate test events

---

## 9. Common Parameter Patterns and Flags

### 9.1 Output Formats

```bash
# Plain text output (good for scripting)
--output text

# JSON format (default, good for jq parsing)
--output json

# ASCII table (good for human reading)
--output table

# YAML format
--output yaml
```

**Use cases:**
- `text`: Store single values in shell variables
- `json`: Parse with jq or programming languages
- `table`: Display for manual review
- `yaml`: Configuration file generation

---

### 9.2 JMESPath Query Patterns

```bash
# Get first item from array
--query 'Items[0]'

# Get specific field
--query 'Stack.StackName'

# Filter array by key value
--query 'Outputs[?OutputKey==`ApiUrl`].OutputValue'

# Get nested field
--query 'Reservations[0].Instances[0].PublicIpAddress'

# Sort and get last item
--query 'sort_by(Images, &CreationDate)[-1].ImageId'

# Multiple fields as list
--query '[StackName,StackStatus]'

# Array of objects with renamed fields
--query 'Images[*].{Name:ImageName,ID:ImageId,Created:CreationDate}'

# Filter and transform
--query 'Instances[?State.Name==`running`].{ID:InstanceId,Type:InstanceType}'

# Count array length
--query 'length(Items)'

# Check if field exists
--query 'Outputs[?OutputKey==`ApiUrl`] | [0] || `not found`'
```

**Common patterns:**
- `[0]`: First element
- `[-1]`: Last element
- `[*]`: All elements
- `?condition`: Filter expression
- `&field`: Sort by field
- `{Key:Value}`: Rename/restructure fields

---

### 9.3 Waiter Commands

```bash
# Wait for EC2 instance to be running
aws ec2 wait instance-running \
    --instance-ids i-1234567890abcdef0 \
    --region us-east-1

# Wait for EC2 instance to stop
aws ec2 wait instance-stopped \
    --instance-ids i-1234567890abcdef0 \
    --region us-east-1

# Wait for EC2 instance termination
aws ec2 wait instance-terminated \
    --instance-ids i-1234567890abcdef0 \
    --region us-east-1

# Wait for CloudFormation stack creation
aws cloudformation wait stack-create-complete \
    --stack-name flask-demo-backend \
    --region us-east-1

# Wait for CloudFormation stack update
aws cloudformation wait stack-update-complete \
    --stack-name flask-demo-backend \
    --region us-east-1

# Wait for CloudFormation stack deletion
aws cloudformation wait stack-delete-complete \
    --stack-name flask-demo-backend \
    --region us-east-1
```

**What it does:** Polls AWS API until resource reaches desired state or timeout.

**Common use cases:**
- Ensure instance is running before attempting SSH
- Wait for deployment to complete before running tests
- Synchronize scripts that depend on resource state

**Default timeouts:**
- EC2 waiters: 40 checks, 15 seconds each (10 minutes total)
- CloudFormation waiters: 120 checks, 30 seconds each (60 minutes total)

---

### 9.4 Filtering Patterns

```bash
# Filter by tag
--filters "Name=tag:Name,Values=jenkins-*"

# Filter by multiple conditions
--filters "Name=instance-state-name,Values=running" \
          "Name=instance-type,Values=t2.small"

# Filter with wildcards
--filters "Name=tag:Environment,Values=demo,prod"

# Filter by VPC
--filters "Name=vpc-id,Values=vpc-123456"
```

**Common filter names:**
- EC2: `instance-state-name`, `instance-type`, `tag:Key`, `vpc-id`
- ECR: `tagStatus` (TAGGED, UNTAGGED, ANY)
- CloudWatch: `log-group-name-prefix`

---

## 10. Command Cheat Sheet by Use Case

### 10.1 Starting a Stopped Jenkins Instance

```bash
# 1. Get instance ID from saved info file
INSTANCE_ID=$(grep "INSTANCE_ID" .jenkins-ec2-demo.info | cut -d= -f2)

# 2. Start instance
aws ec2 start-instances \
    --region us-east-1 \
    --instance-ids $INSTANCE_ID

# 3. Wait for running state
aws ec2 wait instance-running \
    --region us-east-1 \
    --instance-ids $INSTANCE_ID

# 4. Get new public IP
NEW_IP=$(aws ec2 describe-instances \
    --region us-east-1 \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Jenkins is now accessible at: http://$NEW_IP:8080"
```

---

### 10.2 Deploying Lambda from ECR Image

```bash
# 1. Login to ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# 2. Build and tag Docker image
docker build --platform linux/amd64 \
    --provenance=false --sbom=false \
    -t aws-lab-flask-demo:manual-test demo-backend/

# 3. Tag for ECR
docker tag aws-lab-flask-demo:manual-test \
    ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/aws-lab-flask-demo:manual-test

# 4. Push to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/aws-lab-flask-demo:manual-test

# 5. Deploy with SAM
cd aws
sam deploy \
    --config-file samconfig-demo.toml \
    --parameter-overrides ImageTag=manual-test

# 6. Get API URL
API_URL=$(aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoApi`].OutputValue' \
    --output text)

echo "API deployed at: $API_URL"
```

---

### 10.3 Viewing Lambda Logs

```bash
# 1. Get Lambda function name from CloudFormation
FUNCTION_ARN=$(aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoFunction`].OutputValue' \
    --output text)

# Extract function name from ARN (last part after :function:)
FUNCTION_NAME=$(echo $FUNCTION_ARN | cut -d: -f7)

# 2. Find log group name pattern
LOG_GROUP="/aws/lambda/$FUNCTION_NAME"

# 3. Tail logs in real-time
aws logs tail $LOG_GROUP \
    --follow \
    --region us-east-1

# Alternative: Get last 50 lines from past 10 minutes
aws logs tail $LOG_GROUP \
    --since 10m \
    --format short \
    --region us-east-1 | tail -50
```

---

### 10.4 Testing Deployed API

```bash
# 1. Get API URL
API_URL=$(aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoApi`].OutputValue' \
    --output text)

# 2. Test health endpoint
curl -s $API_URL/health | jq

# 3. Test echo endpoint
curl -s -X POST $API_URL/echo \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' | jq

# 4. Check response time
time curl -s $API_URL/health > /dev/null
```

---

### 10.5 Monitoring CloudFormation Deployment

```bash
# 1. Start deployment in background
sam deploy --config-file aws/samconfig-demo.toml &
DEPLOY_PID=$!

# 2. Monitor stack events in real-time
while ps -p $DEPLOY_PID > /dev/null; do
    echo "=== $(date +%H:%M:%S) ==="
    aws cloudformation describe-stack-events \
        --stack-name flask-demo-backend \
        --region us-east-1 \
        --max-items 5 \
        --query 'StackEvents[*].[Timestamp,ResourceStatus,LogicalResourceId]' \
        --output table
    sleep 10
done

# 3. Check final status
aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'Stacks[0].StackStatus' \
    --output text
```

---

### 10.6 Cleaning Up Resources

```bash
# 1. Delete CloudFormation stack (Lambda, API Gateway, logs)
aws cloudformation delete-stack \
    --stack-name flask-demo-backend \
    --region us-east-1

# 2. Wait for deletion
aws cloudformation wait stack-delete-complete \
    --stack-name flask-demo-backend \
    --region us-east-1

# 3. Delete ECR images
aws ecr batch-delete-image \
    --repository-name aws-lab-flask-demo \
    --region us-east-1 \
    --image-ids imageTag=manual-test imageTag=latest

# 4. Stop or terminate Jenkins EC2
# Option A: Stop (keeps EBS, can restart later)
aws ec2 stop-instances \
    --region us-east-1 \
    --instance-ids $INSTANCE_ID

# Option B: Terminate (complete cleanup)
aws ec2 terminate-instances \
    --region us-east-1 \
    --instance-ids $INSTANCE_ID

# 5. Delete security group (after EC2 terminated)
aws ec2 delete-security-group \
    --region us-east-1 \
    --group-id $SECURITY_GROUP_ID
```

---

### 10.7 Troubleshooting Failed Deployment

```bash
# 1. Get stack status
aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'Stacks[0].[StackStatus,StackStatusReason]' \
    --output table

# 2. Get failed events
aws cloudformation describe-stack-events \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[Timestamp,LogicalResourceId,ResourceStatusReason]' \
    --output table

# 3. Check Lambda logs if function was created
aws logs tail /aws/lambda/flask-demo-backend-FlaskDemoFunction-* \
    --since 30m \
    --filter-pattern "ERROR" \
    --region us-east-1

# 4. Validate SAM template
cd aws
sam validate --template template.yaml

# 5. Check if ROLLBACK_COMPLETE (must delete before redeploying)
STATUS=$(aws cloudformation describe-stacks \
    --stack-name flask-demo-backend \
    --region us-east-1 \
    --query 'Stacks[0].StackStatus' \
    --output text)

if [ "$STATUS" == "ROLLBACK_COMPLETE" ]; then
    echo "Stack in ROLLBACK_COMPLETE - deleting..."
    aws cloudformation delete-stack \
        --stack-name flask-demo-backend \
        --region us-east-1
fi
```

---

### 10.8 Cost Monitoring

```bash
# 1. Check EC2 instance running time
aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region us-east-1 \
    --query 'Reservations[0].Instances[0].[LaunchTime,State.Name]' \
    --output table

# 2. Calculate approximate cost
LAUNCH_TIME=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region us-east-1 \
    --query 'Reservations[0].Instances[0].LaunchTime' \
    --output text)

LAUNCH_EPOCH=$(date -d "$LAUNCH_TIME" +%s 2>/dev/null || \
               date -j -f "%Y-%m-%dT%H:%M:%S" "${LAUNCH_TIME%.*}" +%s)
CURRENT_EPOCH=$(date +%s)
HOURS=$(( (CURRENT_EPOCH - LAUNCH_EPOCH) / 3600 ))
COST=$(echo "scale=2; $HOURS * 0.023" | bc)

echo "EC2 running for $HOURS hours, estimated cost: \$$COST"

# 3. Check Lambda invocations (cost metric)
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=flask-demo-backend-FlaskDemoFunction-* \
    --start-time "$(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 86400 \
    --statistics Sum \
    --region us-east-1

# 4. Check ECR repository size
aws ecr describe-repositories \
    --repository-names aws-lab-flask-demo \
    --region us-east-1 \
    --query 'repositories[0].{Name:repositoryName,Size:repositoryUri}'
```

---

## Quick Reference Card

### Most Common Commands

```bash
# EC2
aws ec2 describe-instances --instance-ids i-xxx --query 'Reservations[0].Instances[0].State.Name' --output text
aws ec2 start-instances --instance-ids i-xxx
aws ec2 stop-instances --instance-ids i-xxx

# CloudFormation
aws cloudformation describe-stacks --stack-name STACK --query 'Stacks[0].Outputs' --output table
aws cloudformation describe-stack-events --stack-name STACK --max-items 10 --output table
aws cloudformation delete-stack --stack-name STACK

# ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
aws ecr describe-images --repository-name REPO --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text

# CloudWatch
aws logs tail /aws/lambda/FUNCTION --follow
aws sts get-caller-identity

# SAM
sam validate --template template.yaml
sam build && sam deploy --config-file samconfig.toml
```

---

## Additional Resources

- **AWS CLI Documentation**: https://docs.aws.amazon.com/cli/
- **JMESPath Tutorial**: https://jmespath.org/tutorial.html
- **SAM CLI Reference**: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-command-reference.html
- **CloudFormation User Guide**: https://docs.aws.amazon.com/cloudformation/
- **Project Scripts**: See `scripts/jenkins/` for working examples

---

**Last Updated:** 2025-11-23
**Project:** AWS Flask CI/CD Demo
**Related Files:** `docs/SCRIPT_GUIDE.md`, `CLAUDE.md`
