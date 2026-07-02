output "jenkins_private_ip" {
  value       = aws_instance.jenkins.private_ip
  description = "The private IP address of the Jenkins instance"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app_repo.repository_url
  description = "The URL of the ECR repository"
}