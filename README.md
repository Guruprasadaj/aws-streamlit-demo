# AWS Streamlit Application Demo

This project demonstrates a production-ready deployment of a Streamlit application on AWS using containerization and Infrastructure as Code (IaC).

## Architecture

- **Container Orchestration**: Amazon ECS (Fargate)
- **Container Registry**: Amazon ECR
- **Infrastructure as Code**: Terraform
- **CI/CD**: GitHub Actions & AWS CodeBuild
- **Monitoring**: CloudWatch
- **Auto Scaling**: Scheduled scaling (business hours)

## Prerequisites

- AWS Account
- GitHub Account
- Terraform installed
- AWS CLI configured
- Docker installed (optional)

## Infrastructure Components

- VPC with public subnet
- ECS Cluster with Fargate
- ECR Repository
- CloudWatch Logs and Metrics
- Auto-scaling configuration
- Security Groups
- IAM Roles and Policies

## Deployment Pipeline

1. **Code Push**: Push to main branch triggers workflow
2. **Build**: Docker image built and pushed to ECR
3. **Deploy**: ECS service updated with new image
4. **Scale**: Auto-scales based on schedule
   - Up at 9 AM UTC (weekdays)
   - Down at 5 PM UTC (weekdays)

## Local Development

1. Clone the repository:
git clone https://github.com/Guruprasadaj/aws-streamlit-demo.git
cd aws-streamlit-demo

2. Install dependencies:
bash
pip install -r requirements.txt

3. Run locally:streamlit run app/main.py
## Deployment

1. Initialize Terraform:
cd terraform
terraform init
terraform apply

2. Configure GitHub Secrets:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY

3. Push changes to trigger deployment:
git push origin main

## Monitoring

- Application logs: CloudWatch Logs
- Metrics: CloudWatch Metrics
- Alarms: CPU and Memory utilization

## Security

- Private container registry
- IAM roles with least privilege
- Security groups for network access
- Encrypted secrets management

## Cost Management

- Scheduled scaling to reduce costs
- Fargate spot instances (optional)
- CloudWatch logs retention policy

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
