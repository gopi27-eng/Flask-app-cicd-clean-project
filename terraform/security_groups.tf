# Security Group for Jenkins Server
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-private-sg"
  description = "Allow internal traffic and outbound access"
  vpc_id      = aws_vpc.main.id

  # Inbound traffic for Jenkins web UI (accessible internally within VPC)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] 
  }

  # SSH for debugging (accessible internally within VPC)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Outbound rule allowing Jenkins to hit GitHub, download plugins, and push to ECR
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jenkins-sg" }
}

# Security Group for VPC Endpoints (Allows Jenkins to securely talk to AWS services inside the private subnet)
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Allow HTTPS from Jenkins SG to VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id]
  }

  tags = { Name = "vpc-endpoints-sg" }
}