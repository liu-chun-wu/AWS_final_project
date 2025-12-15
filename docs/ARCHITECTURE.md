# Architecture

This document provides visual architecture diagrams for the AWS Final Project, covering both the AI Generation Application and the CI/CD Pipeline.

## Table of Contents

- [System Overview](#system-overview)
- [Application Architecture](#application-architecture)
- [Data Flow Diagrams](#data-flow-diagrams)
- [CI/CD Pipeline Architecture](#cicd-pipeline-architecture)
- [AWS Infrastructure](#aws-infrastructure)
- [Screenshots](#screenshots)

---

## System Overview

The project consists of two main parts:

1. **AI Generation Application** - Flask backend with AI-powered image and music generation
2. **CI/CD Pipeline** - Automated testing, building, and deployment to AWS Lambda

```mermaid
graph TB
    subgraph "Application"
        Backend[Flask Backend]
        AI[AI Generation APIs]
        Storage[AWS Storage]
    end

    subgraph "CI/CD"
        Git[GitHub]
        Jenkins[Jenkins]
        AWS[AWS Lambda]
    end

    Backend --> AI
    Backend --> Storage
    Git --> Jenkins
    Jenkins --> AWS
```

---

## Application Architecture

### High-Level System Diagram

```mermaid
graph TB
    subgraph "Client Layer"
        Discord[Discord Bot<br/>test-discord-bot.py]
        HTTP[HTTP Client<br/>curl/Postman]
    end

    subgraph "Backend API Layer"
        Flask[Flask Application<br/>src/app.py]

        subgraph "Endpoints"
            Health[GET /health]
            GenImage[POST /generate-image]
            GenAudio[POST /generate-audio]
            Callback[POST /audio-callback]
            History[GET /history]
        end
    end

    subgraph "External AI Services"
        HF[HuggingFace<br/>Stable Diffusion XL]
        Suno[Suno API<br/>Music Generation]
    end

    subgraph "AWS Services"
        S3[S3 Bucket<br/>File Storage]
        DynamoDB[DynamoDB<br/>History Tracking]
    end

    Discord --> Flask
    HTTP --> Flask

    Flask --> Health
    Flask --> GenImage
    Flask --> GenAudio
    Flask --> Callback
    Flask --> History

    GenImage --> HF
    GenImage --> S3
    GenImage -.-> DynamoDB

    GenAudio --> Suno
    Callback --> S3
    Callback --> DynamoDB

    History --> DynamoDB
```

### Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **Flask App** | Request routing, error handling, API orchestration |
| **HuggingFace API** | AI image generation using Stable Diffusion XL |
| **Suno API** | AI music generation (async with webhook) |
| **S3** | Store generated images and audio files |
| **DynamoDB** | Track generation history per user (optional) |

---

## Data Flow Diagrams

### Image Generation Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant B as Backend API
    participant HF as HuggingFace
    participant S3 as AWS S3
    participant DB as DynamoDB

    C->>B: POST /generate-image<br/>{prompt, user_id}
    B->>B: Validate request
    B->>HF: Send prompt to Stable Diffusion XL
    Note over HF: Generate image (~10-15s)
    HF-->>B: Return image bytes
    B->>S3: Upload image<br/>Images/{timestamp}_{uuid}.png
    S3-->>B: Upload success
    B->>B: Generate presigned URL (1hr expiry)
    B->>DB: Save record (non-fatal if fails)
    B-->>C: {success: true, download_url: "..."}
```

### Audio Generation Flow (Async)

```mermaid
sequenceDiagram
    participant C as Client
    participant B as Backend API
    participant Suno as Suno API
    participant S3 as AWS S3
    participant DB as DynamoDB

    C->>B: POST /generate-audio<br/>{prompt, user_id}
    B->>B: Pre-generate S3 key & callback URL
    B->>Suno: Start generation with callback URL
    B-->>C: {success: true, task_id: "...",<br/>download_url: "..."}

    Note over Suno: Generate audio (~1-2 min)

    Suno->>B: POST /audio-callback<br/>{audio_url, task_id}
    B->>Suno: Download generated audio
    Suno-->>B: Audio file
    B->>S3: Upload audio<br/>Audios/{timestamp}_{uuid}.mp3
    S3-->>B: Upload success
    B->>DB: Save record

    Note over C: Audio available at presigned URL
```

---

## CI/CD Pipeline Architecture

### Pipeline Overview

**Philosophy:** Prove → Codify → Automate

```mermaid
graph LR
    subgraph "Phase 1: Local Development"
        Code[Code Changes]
        LocalTest[pytest]
        LocalDocker[Docker Build]
    end

    subgraph "Phase 2: CI Pipeline"
        Push[Git Push]
        JenkinsCI[Jenkins CI Job]
        ECR[ECR Push]
    end

    subgraph "Phase 3: CD Pipeline"
        JenkinsCD[Jenkins CD Job]
        SAM[SAM Deploy]
        Lambda[AWS Lambda]
        APIGW[API Gateway]
    end

    Code --> LocalTest
    LocalTest --> LocalDocker
    LocalDocker --> Push
    Push --> JenkinsCI
    JenkinsCI --> ECR
    ECR --> JenkinsCD
    JenkinsCD --> SAM
    SAM --> Lambda
    Lambda --> APIGW
```

### CI Pipeline Stages

```mermaid
graph TB
    subgraph "Jenkinsfile-CI"
        Checkout[1. Checkout Code]
        Branch[2. Validate Branch<br/>Jeffery only]
        AWS[3. Ensure AWS CLI]
        Venv[4. Setup Python venv]
        Deps[5. Install Dependencies]
        Test[6. Run Tests<br/>Unit + Integration]
        Build[7. Build Docker Image<br/>--platform linux/amd64]
        Push[8. Push to ECR<br/>Tags: BUILD_NUMBER, latest]
    end

    Checkout --> Branch
    Branch --> AWS
    AWS --> Venv
    Venv --> Deps
    Deps --> Test
    Test --> Build
    Build --> Push
```

### CD Pipeline Stages

```mermaid
graph TB
    subgraph "Jenkinsfile-CD"
        Checkout2[1. Checkout Code]
        Branch2[2. Validate Branch]
        AWS2[3. Ensure AWS CLI]
        SAM2[4. Ensure SAM CLI]
        Account[5. Resolve AWS Account]
        Tag[6. Auto-detect Image Tag<br/>or use parameter]
        Deploy[7. SAM Deploy]
        Verify[8. Verify Deployment<br/>/health + /echo]
    end

    Checkout2 --> Branch2
    Branch2 --> AWS2
    AWS2 --> SAM2
    SAM2 --> Account
    Account --> Tag
    Tag --> Deploy
    Deploy --> Verify
```

---

## AWS Infrastructure

### Deployed Resources

```mermaid
graph TB
    subgraph "AWS Cloud"
        subgraph "Container Registry"
            ECR[Amazon ECR<br/>aws-lab-flask-demo]
        end

        subgraph "Compute"
            Lambda[AWS Lambda<br/>Container Runtime]
        end

        subgraph "API"
            APIGW[API Gateway<br/>/health, /echo, /generate-*]
        end

        subgraph "Storage"
            S3[S3 Bucket<br/>Images & Audio]
            DynamoDB2[DynamoDB<br/>UserRecords]
        end

        subgraph "Monitoring"
            CloudWatch[CloudWatch Logs]
        end

        subgraph "CI/CD"
            EC2[EC2 Instance<br/>Jenkins Server]
        end
    end

    ECR --> Lambda
    APIGW --> Lambda
    Lambda --> S3
    Lambda --> DynamoDB2
    Lambda --> CloudWatch
    EC2 --> ECR
```

### AWS Services Explained

| Service | Description |
|---------|-------------|
| **Amazon ECR** | Elastic Container Registry - A fully managed Docker container registry that stores, manages, and deploys container images. We push our Flask application Docker images here for Lambda to pull. |
| **AWS Lambda** | Serverless compute service that runs code without provisioning servers. Our Flask app runs as a container-based Lambda function, scaling automatically with demand. |
| **API Gateway** | Managed service for creating and publishing APIs. Routes HTTP requests to Lambda functions, handling `/health`, `/generate-image`, `/generate-audio`, and `/history` endpoints. |
| **Amazon S3** | Simple Storage Service - Object storage for generated images and audio files. Provides presigned URLs for secure, time-limited file downloads. |
| **Amazon DynamoDB** | Fully managed NoSQL database. Stores user generation history with `user_id` as partition key and `record_id` as sort key. |
| **Amazon CloudWatch** | Monitoring and observability service. Collects Lambda logs, tracks metrics (invocations, errors, duration), and enables debugging. |
| **Amazon EC2** | Elastic Compute Cloud - Virtual servers in the cloud. Hosts our Jenkins CI/CD server for automated builds and deployments. |

### SAM Template Resources

| Resource | Type | Description |
|----------|------|-------------|
| `FlaskDemoFunction` | AWS::Serverless::Function | Lambda function using container image |
| `FlaskDemoApi` | AWS::Serverless::Api | API Gateway with /health and /echo endpoints |
| `LabRole` | (existing) | IAM role for Lambda execution |

### Network Flow

```mermaid
graph LR
    Internet[Internet] --> APIGW[API Gateway]
    APIGW --> Lambda[Lambda]
    Lambda --> S3[S3]
    Lambda --> DynamoDB[DynamoDB]
    Lambda --> External[External APIs<br/>HuggingFace/Suno]
```

---

## Directory Structure Diagram

```
AWS_final_project/
├── backend/                    # Production AI Backend
│   ├── src/
│   │   ├── app.py             # Flask application
│   │   └── db.py              # DynamoDB helpers
│   └── tests/
│
├── demo-backend/               # CI/CD Validation Backend
│   ├── src/
│   │   └── app.py             # Simple Flask app
│   └── tests/
│
├── jenkins-pipeline-setting/   # Pipeline Definitions
│   ├── Jenkinsfile-CI         # CI pipeline
│   └── Jenkinsfile-CD         # CD pipeline
│
├── aws/                        # Infrastructure
│   ├── template.yaml          # SAM template
│   ├── samconfig-demo.toml    # Demo config
│   └── samconfig-prod.toml    # Prod config
│
├── scripts/                    # Automation
│   ├── local/                 # Local testing
│   └── jenkins/               # CI/CD scripts
│
└── docs/                       # Documentation
    ├── ARCHITECTURE.md        # This file
    ├── APPLICATION.md         # Backend docs
    └── CI_CD.md               # Pipeline docs
```

---

## Screenshots

### Jenkins Dashboard

![Jenkins Dashboard](../images/jenkins.jpeg)

### CI/CD Pipelines

**CI Pipeline (Build & Push)**

![CI Pipeline](../images/ci-pipeline.jpeg)

**CD Pipeline (Deploy & Verify)**

![CD Pipeline](../images/cd-pipeline.jpeg)

### AWS Infrastructure

**EC2 Instance (Jenkins Server)**

![EC2 Instance](../images/ec2.jpeg)

**ECR Repository (Container Images)**

![ECR Repository](../images/ECR.jpeg)

### Monitoring

**CloudWatch Dashboard**

![CloudWatch Dashboard](../images/cloudwatch.jpeg)

**CloudWatch Logs**

![CloudWatch Logs](../images/cloudwatch-logs.jpeg)

**CloudWatch Metrics**

![CloudWatch Metrics](../images/cloudwatch-metrics.jpeg)

### GitHub Integration

**Webhook Configuration**

![GitHub Webhook](../images/github-webhook.jpeg)

---

## See Also

- [Application Documentation](APPLICATION.md) - Detailed backend API docs
- [CI/CD Documentation](CI_CD.md) - Pipeline setup and usage
- [Quick Start Guide](QUICK_START.md) - Get started in 5 minutes
