pipeline {
    agent any

    environment {
        AWS_REGION     = 'ap-south-1'
        AWS_ACCOUNT_ID = '463651588282'
        ECR_REPO       = 'ecs-demo-app'
        IMAGE_TAG      = "${BUILD_NUMBER}"
        IMAGE_URI      = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${BUILD_NUMBER}"
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
                        -t ${IMAGE_URI} \
                        -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest \
                        .
                    '''
                }
            }
        }

        stage('Create ECR Repository') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    sh '''
                    echo "Checking ECR repository..."

                    if aws ecr describe-repositories \
                        --repository-names ${ECR_REPO} \
                        --region ${AWS_REGION} > /dev/null 2>&1
                    then
                        echo "ECR repository already exists."
                    else
                        echo "Creating ECR repository..."
                        aws ecr create-repository \
                            --repository-name ${ECR_REPO} \
                            --region ${AWS_REGION}
                    fi

                    echo "ECR repository is ready."
                    '''
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
                    echo "===== AWS Identity ====="
                    aws sts get-caller-identity

                    echo "===== Docker Login ====="
                    aws ecr get-login-password \
                        --region ${AWS_REGION} | \
                        docker login \
                        --username AWS \
                        --password-stdin \
                        ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                    echo "===== Push Image ====="

                    docker push ${IMAGE_URI}

                    docker push \
                        ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest
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

                    echo "===== Region ====="
                    echo ${AWS_REGION}
                    '''
                }
            }
        }

        stage('Get Existing Target Group ARN') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    sh '''
                    echo "===== Target Group ARN ====="

                    aws elbv2 describe-target-groups \
                        --names ecs-demo-tg \
                        --region ${AWS_REGION} \
                        --query 'TargetGroups[0].TargetGroupArn' \
                        --output text
                    '''
                }
            }
        }

        /*
         * IMPORTANT:
         * These resources already exist in AWS.
         * Import them into Terraform state so Terraform
         * does not try to create them again.
         */
        stage('Import Existing Terraform Resources') {
            steps {
                dir('terraform') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'aws-creds']
                    ]) {
                        sh '''
                        set -e

                        export AWS_DEFAULT_REGION=${AWS_REGION}

                        echo "===== Terraform Init ====="
                        terraform init

                        echo "===== Import Target Group ====="

                        terraform import \
                            aws_lb_target_group.app \
                            arn:aws:elasticloadbalancing:ap-south-1:463651588282:targetgroup/ecs-demo-tg/1600285d9c35b2eb || true

                        echo "===== Import S3 State Bucket ====="

                        terraform import \
                            aws_s3_bucket.tf_state \
                            ecs-demo-tf-state-463651588282 || true

                        echo "===== Import DynamoDB Lock Table ====="

                        terraform import \
                            aws_dynamodb_table.tf_locks \
                            terraform-locks || true

                        echo "===== Imports completed ====="

                        terraform state list
                        '''
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'aws-creds']
                    ]) {
                        sh '''
                        set -e

                        export AWS_DEFAULT_REGION=${AWS_REGION}

                        echo "===== Terraform Init ====="
                        terraform init

                        echo "===== Terraform Plan ====="
                        terraform plan
                        '''
                    }
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
                        set -e

                        export AWS_DEFAULT_REGION=${AWS_REGION}

                        echo "===== Terraform Apply ====="

                        terraform apply -auto-approve
                        '''
                    }
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
                    echo "===== Force ECS Deployment ====="

                    aws ecs update-service \
                        --cluster ecs-demo-cluster \
                        --service ecs-demo-service \
                        --force-new-deployment \
                        --region ${AWS_REGION}

                    echo "ECS deployment triggered."
                    '''
                }
            }
        }

        stage('Smoke Test') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    sh '''
                    echo "===== ECS Service Status ====="

                    aws ecs describe-services \
                        --cluster ecs-demo-cluster \
                        --services ecs-demo-service \
                        --region ${AWS_REGION} \
                        --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount}' \
                        --output table

                    echo "===== Load Balancer ====="

                    ALB_DNS=$(aws elbv2 describe-load-balancers \
                        --names ecs-demo-alb \
                        --region ${AWS_REGION} \
                        --query 'LoadBalancers[0].DNSName' \
                        --output text)

                    echo "ALB DNS: http://${ALB_DNS}"

                    echo "===== Smoke Test ====="

                    sleep 10

                    curl -f http://${ALB_DNS}/health

                    echo ""
                    echo "Smoke test successful."
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '========================================='
            echo 'Deployment successful!'
            echo '========================================='
        }

        failure {
            echo '========================================='
            echo 'Deployment failed - check logs'
            echo '========================================='
        }

        always {
            sh '''
            docker system prune -f || true
            '''
        }
    }
}
