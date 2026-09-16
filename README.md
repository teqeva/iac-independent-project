# IaC Independent Project — Terraform + Ansible

An Infrastructure as Code (IaC) project that provisions and configures two Nginx web servers on AWS using **Terraform** and **Ansible**.

Each server hosts a custom web page displaying its hostname, private IP address, operating system information, and deployment timestamp.

## Table of Contents

* [Project Overview](#project-overview)
* [Architecture](#architecture)
* [Key Design Choices](#key-design-choices)
* [Prerequisites](#prerequisites)
* [Project Structure](#project-structure)
* [Backend Setup](#backend-setup)
* [Deployment](#deployment)

  * [Step 1: Provision Infrastructure with Terraform](#step-1-provision-infrastructure-with-terraform)
  * [Step 2: Configure Servers with Ansible](#step-2-configure-servers-with-ansible)
  * [Step 3: Verify the Deployment](#step-3-verify-the-deployment)
* [Idempotency](#idempotency)
* [Security](#security)
* [Cleanup](#cleanup)
* [Evidence](#evidence)
* [Reflection](#reflection)

## Project Overview

This project demonstrates the use of Infrastructure as Code to provision and configure AWS infrastructure in a reproducible way.

### Technologies Used

* Terraform
* Ansible
* AWS EC2
* AWS VPC
* AWS S3
* AWS DynamoDB
* Nginx
* Ubuntu 22.04
* Git
* AWS CLI

### Infrastructure

The deployment consists of:

* One AWS VPC
* One public subnet
* One Internet Gateway
* One route table
* One security group
* Two `t3.micro` EC2 instances
* Nginx installed and configured on both servers
* Remote Terraform state stored in Amazon S3
* DynamoDB used for Terraform state locking

## Architecture

```text
                         Internet
                            |
                            |
                    Internet Gateway
                            |
              +---------------------------+
              |       VPC 10.20.0.0/16    |
              |          eu-west-1         |
              |                            |
              |   Public Subnet            |
              |   10.20.1.0/24             |
              |                            |
              |   Route: 0.0.0.0/0         |
              |          -> IGW             |
              |                            |
              |   Security Group            |
              |   - SSH 22: Admin IP        |
              |   - HTTP 80: Anywhere        |
              |                            |
              |     +------------------+    |
              |     |                  |    |
              |  +-------+        +-------+ |
              |  | web-1 |        | web-2 | |
              |  |t3.micro|       |t3.micro| |
              |  +-------+        +-------+ |
              |  Ubuntu 22.04     Ubuntu 22.04
              |  Nginx             Nginx
              +---------------------------+

                    Terraform State
                          |
                          v
                    Amazon S3 Bucket
                          |
                          +
                          |
                    DynamoDB Locking
```

## Key Design Choices

### Terraform Resource Count

A single `aws_instance` resource uses `count = 2` instead of defining two separate EC2 resources.

This reduces duplication while allowing Terraform to manage both servers consistently.

### SSH Key Management

An Ed25519 SSH key is generated locally.

Only the public key is uploaded to AWS through `aws_key_pair`. The private key remains on the local machine and is never committed to Git.

Generate the key with:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/iac-project -N ""
```

### SSH Security

SSH access is restricted using a CIDR-based security group rule.

The Terraform configuration includes variable validation that rejects:

```text
0.0.0.0/0
```

for the administrator SSH CIDR. This prevents SSH from accidentally being exposed to the entire internet.

### Remote Terraform State

Terraform state is stored remotely in an encrypted and versioned S3 bucket.

DynamoDB is used for state locking to prevent simultaneous Terraform operations from corrupting the state.

### Idempotent Deployment Timestamp

The deployment timestamp is written to the server only during the first Ansible deployment.

Ansible reads the existing timestamp on later runs instead of generating a new timestamp every time.

This allows the web page to display the original deployment time while ensuring subsequent Ansible runs remain idempotent.

## Prerequisites

Before starting, ensure the following are available:

* Terraform >= 1.5
* AWS CLI v2
* Git
* Ansible
* An AWS IAM user with the required permissions
* An AWS account
* An SSH key pair

Required AWS permissions include access to:

* EC2
* VPC
* S3
* DynamoDB

Ansible can be run from AWS CloudShell if the local network blocks outbound SSH traffic.

## Project Structure

```text
iac-independent-project/
├── README.md
├── terraform/
│   ├── backend.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── .gitignore
├── ansible/
│   ├── ansible.cfg
│   ├── site.yml
│   ├── requirements.yml
│   ├── group_vars/
│   │   └── all.yml
│   ├── roles/
│      └── webserver/
│          ├── defaults/main.yml
│          ├── tasks/main.yml
│          ├── handlers/main.yml
│          └── templates/index.html.j2
└── evidence/
    ├── terraform-plan.txt
    ├── terraform-apply.txt
    ├── ansible-run-1.txt
    ├── ansible-run-2.txt
    ├── terraform-destroy.txt
    └── screenshots/
        ├── browser_output_1.png
        ├── browser_output_2.png
        ├── successful_playbook_ansible_1.png
        ├── successful_playbook_ansible_2.png
        ├── terraform_apply.png
        └── terraform_plan.png
```

## Backend Setup

The Terraform backend must be created before running `terraform init`.

First, retrieve the AWS account ID:

```bash
export ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)
```

Create the S3 bucket:

```bash
aws s3api create-bucket \
  --bucket "iac-project-tfstate-${ACCOUNT_ID}" \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1
```

Create the DynamoDB locking table:

```bash
aws dynamodb create-table \
  --table-name iac-project-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-1
```

Update `terraform/backend.tf` with the correct S3 bucket name.

## Deployment

The deployment follows this order:

```text
Terraform
   |
   v
AWS Infrastructure
   |
   v
EC2 Public IPs
   |
   v
Ansible Inventory
   |
   v
Ansible Configuration
   |
   v
Nginx Web Servers
   |
   v
Verification
```

### Step 1: Provision Infrastructure with Terraform

Navigate to the Terraform directory:

```bash
cd terraform
```

Create the variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your public IP address.

Example:

```hcl
admin_ip_cidr = "203.0.113.5/32"
```

Then initialize Terraform:

```bash
terraform init
```

Format the configuration:

```bash
terraform fmt -recursive
```

Validate the configuration:

```bash
terraform validate
```

Create the execution plan:

```bash
terraform plan -out=tfplan
```

Apply the plan:

```bash
terraform apply tfplan
```

Display the Terraform outputs:

```bash
terraform output
```

The outputs should provide the public IP addresses needed for the Ansible inventory.

### Step 2: Configure Servers with Ansible

Move into the Ansible directory:

```bash
cd ../ansible
```

Install the required Ansible collection:

```bash
ansible-galaxy collection install -r requirements.yml
```

Create `inventory.ini` using the public IP addresses returned by Terraform.

Example:

```ini
[web]
web-1 ansible_host=<web-1-public-ip>
web-2 ansible_host=<web-2-public-ip>

[web:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/iac-project
```

Test connectivity:

```bash
ansible web -m ping
```

Run the playbook:

```bash
ansible-playbook site.yml
```

The playbook installs and configures Nginx and deploys the custom web page to both servers.

### Step 3: Verify the Deployment

Use `curl` with the public IP address of each server:

```bash
curl http://<web-1-public-ip>
curl http://<web-2-public-ip>
```

Alternatively, open both IP addresses in a web browser.

Each server should display:

* Hostname
* Private IP address
* Operating system information
* Deployment timestamp

The hostname should differ between `web-1` and `web-2`, confirming that both servers are responding independently.

## Idempotency

An important requirement of the project is that the Ansible playbook is **idempotent**.

The first run performs the required configuration:

```text
Run 1:
web-1 ok=13 changed=5 failed=0
web-2 ok=13 changed=5 failed=0
```

The second run should make no further changes:

```text
Run 2:
web-1 ok=12 changed=0 failed=0
web-2 ok=12 changed=0 failed=0
```

The `changed=0` result on the second run demonstrates that the playbook does not repeatedly modify resources that are already in the desired state.

### Timestamp Problem

The initial version of the playbook rendered `ansible_date_time` directly into the template.

Because the timestamp could change between runs, Ansible detected a difference every time and continued reporting changes.

The solution was to:

1. Create the deployment timestamp once.
2. Prevent it from being overwritten.
3. Read the existing timestamp on subsequent runs.
4. Pass the stored timestamp to the Nginx template.

This preserves the original deployment time and maintains idempotency.

## Security

The project includes several security controls.

### SSH Access

SSH is restricted to the administrator's IP address.

The Terraform configuration prevents:

```text
0.0.0.0/0
```

from being used for normal administrator SSH access.

### SSH Private Key

The private SSH key remains on the local machine.

It is not uploaded to AWS and must never be committed to the repository.

### Sensitive Files

The following files should not be committed:

```text
*.pem
*.tfvars
*.tfstate
inventory.ini
```

These are excluded through `.gitignore`.

### EBS Encryption

The root EBS volumes are encrypted.

### IMDSv2

IMDSv2 is required on both EC2 instances.

### S3 State Security

The Terraform state bucket is configured with:

* Versioning
* Encryption
* Public access blocking

Terraform state can contain sensitive infrastructure information, so it should not be exposed publicly.

## Cleanup

When the project is complete, destroy the AWS infrastructure:

```bash
cd terraform
terraform destroy
```

Verify the Terraform state:

```bash
terraform show
```

Confirm that no project instances remain running:

```bash
aws ec2 describe-instances \
  --filters \
  "Name=tag:Project,Values=iac-project" \
  "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId"
```

The command should return no running instances after the destroy operation has completed.

## Evidence

The following evidence is included in the project:

| Evidence           | Location                         |
| ------------------ | -------------------------------- |
| Terraform plan     | `evidence/terraform-plan.txt`    |
| Terraform apply    | `evidence/terraform-apply.txt`   |
| First Ansible run  | `evidence/ansible-run-1.txt`     |
| Second Ansible run | `evidence/ansible-run-2.txt`     |
| Curl verification  | `evidence/curl-verification.txt` |
| Terraform destroy  | `evidence/terraform-destroy.txt` |
| Screenshots        | `evidence/screenshots/`          |

The Ansible evidence demonstrates idempotency by comparing the first and second playbook runs.

## Reflection

### What Failed Initially

The first SSH connection attempt to the newly provisioned EC2 instances failed because the home ISP was blocking outbound traffic on port 22.

The issue was investigated using `nc` connectivity tests.

Port 80 was reachable, while port 22 consistently timed out. A fallback test using port 2222 produced the same result.

This showed that changing the AWS security group alone would not solve the problem because the restriction was occurring outside the AWS environment.

### What Was Fixed

AWS EC2 Instance Connect was used through the browser to access the instances for troubleshooting.

For the actual Ansible deployment, AWS CloudShell was used because it runs within the AWS environment rather than depending on the local ISP's outbound SSH connectivity.

The additional access rules required for troubleshooting and CloudShell were defined through Terraform instead of being manually added through the AWS console.

This keeps the infrastructure reproducible from the project configuration.

### What Was Learned About Idempotency

The first version of the Ansible configuration generated a new deployment timestamp every time the playbook ran.

This caused Ansible to detect a change during every execution.

The configuration was redesigned to save the deployment timestamp once and reuse it on later runs.

As a result, the second Ansible run reports:

```text
changed=0
```

## Conclusion

This project demonstrates a complete Infrastructure as Code workflow using Terraform and Ansible.

Terraform is responsible for provisioning the AWS infrastructure, while Ansible configures the EC2 instances and deploys the Nginx web application.

The project also demonstrates:

* AWS infrastructure provisioning
* Remote Terraform state management
* Infrastructure security
* SSH key management
* Configuration management
* Ansible idempotency
* Troubleshooting network connectivity
* Infrastructure cleanup
* Reproducible deployments
