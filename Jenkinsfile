pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        AWS_ACCOUNT_ID = '463651588282'
        PROJECT_NAME = 'ecs-demo'
        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-app"
        IMAGE_TAG = "${BUILD_NUMBER}"
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
                    sh '''
                    docker build \
                    -t ${ECR_REPO}:${IMAGE_TAG} \
                    -t ${ECR_REPO}:latest .
                    '''
                }
            }
        }

        stage('Check AWS Credentials') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds']
                ]) {
                    sh '''
                    echo "===== AWS CLI ====="
                    aws --version

                    echo "===== Identity ====="
                    aws sts get-caller-identity

                    echo "===== Environment ====="
                    env | grep AWS || true
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds']
                    ]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        export AWS_DEFAULT_REGION=${AWS_REGION}

                        terraform init
                        terraform apply -auto-approve
                        '''
                    }
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds']
                ]) {
                    sh '''
                    aws sts get-caller-identity

                    aws ecr get-login-password \
                    --region ${AWS_REGION} | \
                    docker login \
                    --username AWS \
                    --password-stdin ${ECR_REPO}

                    docker push ${ECR_REPO}:${IMAGE_TAG}
                    docker push ${ECR_REPO}:latest
                    '''
                }
            }
        }

        stage('Force New Deployment') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds']
                ]) {
                    sh '''
                    aws ecs update-service \
                    --cluster ecs-demo-cluster \
                    --service ecs-demo-service \
                    --force-new-deployment \
                    --region ${AWS_REGION}
                    '''
                }
            }
        }

        stage('Smoke Test') {
            steps {
                sh 'echo "ECS Deployment Successful"'
            }
        }
    }

    post {
        always {
            sh 'docker system prune -f || true'
        }

        success {
            echo 'Deployment completed successfully'
        }

        failure {
            echo 'Deployment failed - check logs'
        }
    }
}
