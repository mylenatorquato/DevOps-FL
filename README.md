# Snake Game CI/CD Pipeline

## Overview
This project is a simple Snake Game built in HTML. The goal is to test and train CI/CD skills using Jenkins, Terraform, Docker, and Kubernetes on AWS.

## Tech Stack
- **Jenkins**: Used for CI/CD automation
- **Terraform**: Infrastructure as Code (IaC) for provisioning the environment and Jenkins EC2 instance
- **Docker**: Containerizes the application
- **Kubernetes**: Orchestrates the application
- **Amazon Elastic Kubernetes Service (EKS)**: Manages Kubernetes cluster

---

## Architecture
1. **Terraform** provisions:
   - An EC2 instance for Jenkins
   - EKS cluster for deployment
   
2. **Jenkins Pipeline**:
   - Pulls the latest code from the repository
   - Builds the Docker image and pushes it to Amazon Elastic Container Registry (ECR)
   - Deploys the application to EKS using Kubernetes manifests

3. **Kubernetes** deploys and manages the application

---

## Setup and Deployment

### 1. Setup Jenkins on EC2
Use Terraform to create an EC2 instance and install Jenkins:
```bash
terraform init
terraform apply
```
Access Jenkins via `http://<EC2-IP>:8080`.
s
### 2. Configure Jenkins Pipeline
- Install required plugins: Docker, Kubernetes, Terraform, AWS CLI
- Create a pipeline with the following steps:
  1. Pull code from GitHub
  2. Build Docker image and run
  3. Apply Kubernetes manifests to deploy the application

### 3. Build and Deploy the Application
Run the pipeline in Jenkins to automate:
```bash
kubectl apply -f deployment.yaml
```
Check if the app is running:
```bash
kubectl get pods -n snake-game
```
Access the game via the EKS LoadBalancer IP.

---

## Files Structure
```
├── terraform/
│   ├── main.tf  
├── jenkins/
│   ├── Jenkinsfile 
├── app/
│   ├── index.html  
│   ├── Dockerfile  
│   ├── app.py  
├── kubernetes/
│   ├── deployment.yaml  
```

---

## Next Steps
- Improve the pipeline by adding automated testing
- Implement monitoring using Prometheus and Grafana
- Scale the application with Kubernetes auto-scaling

---

## License
This project is for learning purposes only.

