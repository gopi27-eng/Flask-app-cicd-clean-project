pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPO   = '238788379449.dkr.ecr.us-east-1.amazonaws.com/my-devops-app'
        IMAGE_NAME = 'my-flask-app'
    }

    stages {
        stage('Checkout Code') {
            steps {
                // Pulls the code from the Git repository configured in the Jenkins UI
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building the Docker image..."
                sh "docker build -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Authenticate & Push to ECR') {
            steps {
                script {
                    echo "Logging into AWS ECR..."
                    // Uses the EC2 IAM Role automatically—no hardcoded credentials!
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}"
                    
                    echo "Tagging and pushing image..."
                    sh "docker tag ${IMAGE_NAME}:latest ${ECR_REPO}:latest"
                    sh "docker tag ${IMAGE_NAME}:latest ${ECR_REPO}:${BUILD_NUMBER}" // Tags with Jenkins build ID
                    
                    sh "docker push ${ECR_REPO}:latest"
                    sh "docker push ${ECR_REPO}:${BUILD_NUMBER}"
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                // Free up disk space on the Jenkins server after a successful push
                sh "docker rmi ${IMAGE_NAME}:latest ${ECR_REPO}:latest ${ECR_REPO}:${BUILD_NUMBER} || true"
            }
        }
    }
}