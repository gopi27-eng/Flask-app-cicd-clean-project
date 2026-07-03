# 1. Scoped IAM Policy for Secrets Manager (Least Privilege)
resource "aws_iam_policy" "jenkins_secrets_policy" {
  name        = "JenkinsSecretsManagerReadPolicy"
  description = "Allows Jenkins to only read its specific pipeline secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:jenkins/pipeline/*"
      }
    ]
  })
}

# 2. IAM Role for EC2 to access ECR and Secrets Manager
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-ecr-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# Attachment 1: ECR Permissions
resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Attachment 2: Secrets Manager Permissions
resource "aws_iam_role_policy_attachment" "secrets_policy_attach" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = aws_iam_policy.jenkins_secrets_policy.arn
}

# IAM Instance Profile to attach to the EC2 Instance
resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-instance-profile-v3"
  role = aws_iam_role.jenkins_role.name
}

# Attachment 3: SSM Permissions (Allows secure tunneling)
resource "aws_iam_role_policy_attachment" "ssm_policy_attach" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. AWS Private VPC Endpoint for Secrets Manager 
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.secretsmanager" 
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private.id]
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]

  tags = { Name = "secretsmanager-vpc-endpoint" }
}

# 4. Jenkins EC2 Instance in Private Subnet
resource "aws_instance" "jenkins" {
  ami                  = "ami-0b6d9d3d33ba97d99" # Ubuntu 22.04 LTS in us-east-1
  instance_type        = "t3.small"             
  subnet_id            = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  iam_instance_profile = aws_iam_instance_profile.jenkins_profile.id

  # PROPERLY NESTED STORAGE BLOCK
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              
              # Install Java 21 (Updated for modern Jenkins)
              sudo apt-get install openjdk-21-jdk -y

              # Install AWS CLI
              sudo apt-get install unzip -y
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              sudo ./aws/install

              # Install Jenkins (Updated with 2026 Key)
              sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
                https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
              echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
                https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
                /etc/apt/sources.list.d/jenkins.list > /dev/null
              sudo apt-get update -y
              sudo apt-get install jenkins -y
              sudo systemctl start jenkins
              sudo systemctl enable jenkins

              # Install Docker
              sudo apt-get install ca-certificates curl gnupg lsb-release -y
              sudo mkdir -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt-get update -y
              sudo apt-get install docker-ce docker-ce-cli containerd.io -y
              
              # Add jenkins user to docker group
              sudo usermod -aG docker jenkins
              sudo systemctl restart jenkins
              EOF

  tags = { Name = "Jenkins-Private-Server" }
}