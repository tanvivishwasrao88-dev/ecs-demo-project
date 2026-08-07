# ECS Fargate + ALB + Jenkins CI/CD Demo

A Flask app, containerized, deployed on AWS ECS Fargate behind an Application
Load Balancer, provisioned with Terraform, deployed via Jenkins, with
CloudWatch monitoring.

## Architecture

```
GitHub push -> Jenkins -> Docker build -> ECR -> Terraform apply -> ECS Fargate (2 tasks, public subnets) -> ALB -> Internet
                                                                          |
                                                                    CloudWatch Logs + Alarms -> SNS
```

- **VPC**: custom VPC, 2 public subnets across 2 AZs (no NAT/private subnets tonight — see note below)
- **Compute**: ECS Fargate service, 2 tasks, auto-restarts unhealthy tasks
- **Load Balancer**: ALB with HTTP listener, target group health-checked on `/health`
- **CI/CD**: Jenkins pipeline builds image, pushes to ECR, runs `terraform apply`, forces new deployment, smoke tests
- **State**: remote Terraform state in S3, locking via DynamoDB
- **Monitoring**: CloudWatch alarms on unhealthy host count and high CPU, wired to an SNS topic

## Repo layout

```
.
├── app/                 # Flask app + Dockerfile
├── terraform/           # All infra as code
├── Jenkinsfile          # CI/CD pipeline
└── README.md
```

## Step-by-step setup

### 1. Prereqs
- AWS account (your student credits work fine here) + AWS CLI configured (`aws configure`)
- Terraform >= 1.5
- Docker
- A Jenkins instance (local Docker container is fine) with the AWS CLI, Docker, and Terraform available on the agent

### 2. Bootstrap remote state (one-time, run locally)
```bash
cd terraform
terraform init
terraform apply -target=aws_s3_bucket.tf_state -target=aws_dynamodb_table.tf_locks
```
Copy the bucket name from the output, put it into the `backend "s3" {}` block in
`versions.tf`, uncomment that block, then:
```bash
terraform init   # will offer to migrate local state to S3 - say yes
```

### 3. First manual deploy (to get something live before wiring Jenkins)
```bash
# Build & push the first image manually
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
cd ../app
docker build -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-app:latest .
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-app:latest

# Now provision everything else
cd ../terraform
terraform apply -var="container_image=<account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-demo-app:latest"
```
Grab the URL:
```bash
terraform output alb_dns_name
```
Open it in a browser — you should see the JSON response from the Flask app.

### 4. Wire up Jenkins
In Jenkins, add credentials:
- `aws-creds` — AWS access key/secret (AmazonWebServicesCredentialsBinding type)
- `aws-account-id` — Secret text, your 12-digit AWS account ID

Create a Pipeline job pointing at this repo, using the included `Jenkinsfile`.
Push to `main` (or trigger manually) — the pipeline builds, pushes, applies
Terraform, and force-deploys the new task.

### 5. Verify self-healing (nice demo moment)
```bash
# Kill a task manually and watch ECS replace it
aws ecs list-tasks --cluster ecs-demo-cluster --service-name ecs-demo-service
aws ecs stop-task --cluster ecs-demo-cluster --task <task-id>
# Refresh the ALB URL a few times — service stays up, ECS spins up a replacement task automatically
```

## Notes / deliberate scope decisions

- **Public subnets, no NAT gateway**: tasks run in public subnets with security
  groups restricting inbound to the ALB only. A production setup would put
  tasks in private subnets behind a NAT gateway — omitted here as a
  time/complexity trade-off, not a security requirement for a demo. Documented
  here so it's clear this was a deliberate choice, not an oversight.
- **Self-healing**: ECS's own service scheduler already replaces failed tasks
  automatically — that's the actual self-healing mechanism. CloudWatch alarms
  + SNS give visibility on top; a Lambda subscriber can be added to `monitoring.tf`
  for custom remediation if there's time.

## Teardown
```bash
cd terraform
terraform destroy
```
(Do this before your credits/free tier assumptions change — Fargate + ALB are
not free, they're just covered by your credits.)
