pipeline {
    agent any

    environment {
        AWS_REGION       = 'us-east-1'
        PROJECT_NAME     = 'ecs-demo'
        AWS_ACCOUNT_ID    = credentials('aws-account-id')       // Jenkins credential (secret text)
        ECR_REPO          = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-app"
        IMAGE_TAG         = "${env.BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('app') {
                    sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} -t ${ECR_REPO}:latest ."
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                          docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        docker push ${ECR_REPO}:${IMAGE_TAG}
                        docker push ${ECR_REPO}:latest
                    """
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    dir('terraform') {
                        sh """
                            terraform init -input=false
                            terraform apply -auto-approve \
                              -var="container_image=${ECR_REPO}:${IMAGE_TAG}"
                        """
                    }
                }
            }
        }

        stage('Force New Deployment') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh """
                        aws ecs update-service \
                          --cluster ${PROJECT_NAME}-cluster \
                          --service ${PROJECT_NAME}-service \
                          --force-new-deployment \
                          --region ${AWS_REGION}
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    dir('terraform') {
                        sh """
                            sleep 30
                            ALB_URL=\$(terraform output -raw alb_dns_name)
                            curl -f \$ALB_URL/health || exit 1
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Deployment succeeded.'
        }
        failure {
            echo 'Deployment failed - check logs above.'
        }
        always {
            sh 'docker system prune -f || true'
        }
    }
}
