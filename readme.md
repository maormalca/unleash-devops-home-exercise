# Unleash Devops Home Exercise

This repository contains an node Express server written in TypeScript that hosts an endpoint to check if a file exists in a specified S3 bucket. 

`GET /check-file?fileName=myfile.txt`

## Configuration

The following environment variables needs to be configured in the server:
- BUCKET_NAME
- PORT - (Default to 3000 if not specified)

## Tasks

### 1. Dockerization

Dockerize the server using best practices.

### 2. Continuous Integration (CI)

Set up a CI process using your preferred CI tool (e.g., GitHub Actions, GitLab CI, Azure Pipelines):

- Configure the CI pipeline to build and push a Docker image to a Docker registry on every commit to the main branch.

### 3. Continuous Deployment (CD)

Enhance the CI pipeline to include a CD stage:

- Automate the deployment of the Docker image to a cloud environment.
- Ensure the CD process deploys the service and its dependencies (e.g., the S3 bucket) in a robust, reproducible, and scalable manner.
- Apply infrastructure as code principles where appropriate.

**Note**: The infrastructure of the service (where this service runs) doesn't have to be managed as infrastructure as code within this repository.

---
---

## Overview

**Tech Stack:**
- **Application:** Node.js 20, TypeScript, Express, AWS SDK v3
- **Container:** Docker (multi-stage build)
- **Orchestration:** Kubernetes (AWS EKS)
- **Infrastructure:** Terraform
- **CI/CD:** GitHub Actions
- **Cloud Provider:** AWS (ECR, EKS, S3, IAM)

---

## Dockerization

The application uses a **multi-stage Docker build** to optimize image size and security.

### Build Process

**Stage 1: Builder**
- Base image: `node:20-alpine`
- Installs all dependencies (including devDependencies)
- Compiles TypeScript to JavaScript
- Output: `/app/dist` directory with compiled code

**Stage 2: Runner**
- Base image: `node:20-alpine`
- Copies only production dependencies and compiled code from builder
- No TypeScript compiler or source files included
- Exposes port 3000
- Runs compiled JavaScript with Node.js

### Benefits

1. **Reduced Image Size:** Final image contains only runtime dependencies and compiled code
2. **Security:** No build tools or source code in production image
3. **Layer Caching:** Dependency installation cached separately from source code compilation
4. **Best Practice:** Separates build-time and runtime concerns

---

## CI/CD Pipelines

### CI Pipeline

**Trigger:** Push to `master` branch

**Process:**
1. Checkout repository
2. Authenticate to AWS using access keys stored in GitHub Secrets
3. Login to Amazon ECR
4. Query ECR repository URI dynamically
5. Build Docker image using multi-stage Dockerfile
6. Tag image with `:latest`
7. Push image to ECR

**Authentication Method:**
The CI pipeline uses **AWS access keys** ( maor.malca) stored as GitHub repository secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`

### CD Pipeline

**Trigger:** Successful completion of CI Pipeline (`workflow_run`)

**Process:**
1. Checkout repository
2. Authenticate to AWS
3. Configure `kubectl` to access EKS cluster
4. Dynamically retrieve infrastructure values:
   - IAM role ARN for IRSA
   - S3 bucket name (dynamic identifier)
5. Update Kubernetes manifests with the dynamic values
6. Apply manifests to EKS cluster (`kubectl apply -f k8s/`)
7. Wait for deployment rollout to complete
8. Display LoadBalancer endpoint for testing

### Infrastructure Pipeline

**Trigger:**
- Manual dispatch via GitHub Actions UI
- Push to `master` with changes to `terraform/**`

**Actions Available:**
- `apply`: Create/update infrastructure
- `destroy`: delete all resources

**Process:**
1. Checkout repository
2. Authenticate to AWS
3. Setup Terraform CLI
4. Initialize Terraform backend (S3)
5. Execute `terraform apply` or `terraform destroy`

---

## Infrastructure as Code

### Terraform Resources

**Core Infrastructure:**
- **VPC & Subnets:** Uses default VPC for simplicity (production should use custom VPC with private subnets)
- **EKS Cluster:** Kubernetes 1.29 with public endpoint access
- **Managed Node Group:** 2x `t3.medium` instances (min: 1, max: 2, desired: 2)
- **S3 Bucket:** Storage for application files
- **ECR Repository:** Docker image registry

**IAM & IRSA Configuration:**
- **OIDC Provider:** Enables IRSA (created by EKS module)
- **IAM Policy:** Grants S3 permissions (`GetObject`, `PutObject`, `ListBucket`, `HeadObject`)
- **IAM Role for Service Accounts (IRSA):**
  - Role name: `unleash-exercise-cluster-app-role`
  - Trust policy: Only allows `default:app-sa` ServiceAccount to assume role
  - Attached policy: S3 access permissions

**State Management:**
- Terraform state stored in S3 bucket: `unleash-terraform-state-maor-malca`
- Region: `eu-north-1`

### IRSA (IAM Roles for Service Accounts)

IRSA provides secure, pod-level AWS access without embedding credentials:

1. EKS cluster creates an OIDC identity provider
2. Kubernetes ServiceAccount annotated with IAM role ARN
3. Pods using the ServiceAccount receive temporary AWS credentials via a webhook
4. AWS SDK automatically uses these credentials to access S3

**Security Benefits:**
- No hardcoded access keys
- No shared credentials across pods
- Automatic credential rotation
- Fine-grained permissions per ServiceAccount

---

## Security

**Authentication & Authorization:**
- **IRSA:** Pods access S3 using temporary credentials via IAM roles
- **No Credentials in Code:** AWS SDK uses ambient credentials from IRSA
- **Least Privilege:** IAM policy grants only required S3 permissions

**Container Security:**
- Multi-stage build reduces attack surface
- Alpine Linux base image (minimal footprint)
- No build tools in runtime image

**Network Security:**
- LoadBalancer exposes only port 80
- Application runs on port 3000 (internal)
- EKS security groups control cluster access

---

## Deployment

### 1. Deploy Infrastructure

**Option A: Via GitHub Actions**
1. Navigate to **Actions** tab in GitHub
2. Select **Infrastructure Pipeline**
3. Click **Run workflow**
4. Choose `apply` action
5. Monitor logs for completion

**Output:**
```
Outputs:
cluster_name = "unleash-exercise-cluster"
configure_kubectl = "aws eks update-kubeconfig --region eu-north-1 --name unleash-exercise-cluster"
ecr_repository_url = "532150070616.dkr.ecr.eu-north-1.amazonaws.com/unleash-exercise-repo"
irsa_role_arn = "arn:aws:iam::532150070616:role/unleash-exercise-cluster-app-role"
s3_bucket_name = "unleash-exercise-bucket-12345"
```

### 2. Build and Push Docker Image

Push to `master` branch to trigger CI pipeline:

### 3. Deploy Application

CD pipeline triggers automatically after successful CI build.

### 4. Get LoadBalancer Endpoint

```bash
kubectl get svc app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Wait 2-3 minutes for AWS to provision the LoadBalancer.

---

## Testing

### Upload Test File to S3

```bash
echo "test content" > test.txt
aws s3 cp test.txt s3://unleash-exercise-bucket-12345/test.txt
```

**Note:** I already did that so you can skip the Upload Test File to S3 (if you destroy and apply the infra again you need to do it)

### Test API Endpoint

```bash
# Get LoadBalancer URL
LB_URL=$(kubectl get svc app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test existing file
curl "http://$LB_URL/check-file?fileName=test.txt"
```

---

## Cleanup

### Destroy Infrastructure

Run the infra pipeline with `destroy` action

**Note:** You need to manually delete ECR images before destroying infrastructure:
```bash
aws ecr batch-delete-image \
  --repository-name unleash-exercise-repo \
  --image-ids imageTag=latest
```

---

## Project Structure
## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── ci-pipeline.yml          # Build and push Docker image
│       ├── cd-pipeline.yml          # Deploy to EKS
│       └── infra-pipeline.yml       # Terraform automation
├── k8s/
│   ├── deployment.yaml              # Pod specification
│   ├── service.yaml                 # LoadBalancer configuration
│   └── serviceaccount.yaml          # IRSA annotation
├── terraform/
│   ├── main.tf                      # EKS, S3, ECR, IRSA resources
│   ├── variables.tf                 # Input variables
│   └── outputs.tf                   # Output values
├── dockerfile                       # Multi-stage Docker build
├── index.ts                         # Express application
├── package.json                     # Node.js dependencies
├── tsconfig.json                    # TypeScript configuration
└── README.md                        # This file
```

```

---
