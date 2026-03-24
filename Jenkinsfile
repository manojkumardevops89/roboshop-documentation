pipeline {
    agent any
    environment {
        AWS_REGION   = 'us-east-1'
        ECR_REGISTRY = credentials('ecr-registry')
        ECR_REPO     = 'roboshop'
        IMAGE_TAG    = "${BUILD_NUMBER}"
        CLUSTER_NAME = 'roboshop-eks-cluster'
        NAMESPACE    = 'roboshop'
        APP_URL      = credentials('app-url')
    }
    stages {
        // ── 1. CHECKOUT ───────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/manojkumardevops89/roboshop-documentation.git'
            }
        }
        // ── 2. BUILD ──────────────────────────────────────────────────────
        stage('Build') {
            steps {
                sh '''
                    for svc in frontend cart user payment; do
                        cd services/$svc && npm install && cd -
                    done
                    cd services/shipping && mvn clean package -q && cd -
                    for svc in catalogue dispatch; do
                        cd services/$svc && go build ./... && cd -
                    done
                '''
            }
        }
        // ── 3. SONARQUBE SCAN ─────────────────────────────────────────────
        stage('SonarQube Scanner') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=roboshop \
                          -Dsonar.sources=services \
                          -Dsonar.java.binaries=services/shipping/target/classes
                    '''
                }
                timeout(time: 2, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        // ── 4. DOCKER IMAGE BUILD ─────────────────────────────────────────
        stage('Docker Image Build') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} \
                          | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        for svc in frontend cart user payment; do
                            docker build -t ${ECR_REGISTRY}/${ECR_REPO}/\$svc:${IMAGE_TAG} \
                                -f docker/nodejs.Dockerfile services/\$svc
                        done
                        docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} \
                            -f docker/java.Dockerfile services/shipping
                        for svc in catalogue dispatch; do
                            docker build -t ${ECR_REGISTRY}/${ECR_REPO}/\$svc:${IMAGE_TAG} \
                                -f docker/golang.Dockerfile services/\$svc
                        done
                    """
                }
            }
        }
        // ── 5. TRIVY SCAN ─────────────────────────────────────────────────
        stage('Trivy Scanner') {
            steps {
                sh """
                    for svc in frontend cart user payment shipping catalogue dispatch; do
                        trivy image --severity CRITICAL,HIGH --exit-code 1 \
                            ${ECR_REGISTRY}/${ECR_REPO}/\$svc:${IMAGE_TAG}
                    done
                """
            }
        }
        // ── 6. PUSH TO ECR ────────────────────────────────────────────────
        stage('ECR') {
            steps {
                sh """
                    for svc in frontend cart user payment shipping catalogue dispatch; do
                        docker push ${ECR_REGISTRY}/${ECR_REPO}/\$svc:${IMAGE_TAG}
                    done
                """
            }
        }
        // ── 7. TERRAFORM ──────────────────────────────────────────────────
        stage('Terraform') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    dir('Terraform') {
                        sh '''
                            terraform init
                            terraform plan
                            terraform apply -auto-approve
                        '''
                    }
                }
            }
        }
        // ── 8. K8S DEPLOY (EKS) ───────────────────────────────────────────
        stage('K8s Deploy') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                        for svc in frontend cart user payment shipping catalogue dispatch; do
                            helm upgrade --install \$svc helm/\$svc \
                                --namespace ${NAMESPACE} --create-namespace \
                                --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/\$svc \
                                --set image.tag=${IMAGE_TAG} \
                                --atomic --timeout 5m
                        done
                        kubectl apply -f kubernetes/ingress.yaml -n ${NAMESPACE}
                    """
                }
            }
        }
        // ── 9. OWASP ZAP ─────────────────────────────────────────────────
        stage('OWASP Scanner') {
            steps {
                sh """
                    docker run --rm \
                        -v \$(pwd)/zap-reports:/zap/wrk/:rw \
                        ghcr.io/zaproxy/zaproxy:stable \
                        zap-baseline.py -t ${APP_URL} -r zap-report.html -I
                """
            }
        }
        // ── 10. PROWLER ───────────────────────────────────────────────────
        stage('Prowler') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        prowler aws --region ${AWS_REGION} \
                            --services iam s3 eks ec2 \
                            --severity high critical
                    """
                }
            }
        }
        // ── 11. CLOUDWATCH ────────────────────────────────────────────────
        stage('CloudWatch') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        # Install CloudWatch agent on EKS using Helm
                        helm repo add aws-cloudwatch \
                            https://aws.github.io/eks-charts 2>/dev/null || true
                        helm repo update

                        # Deploy CloudWatch Container Insights
                        helm upgrade --install aws-cloudwatch-metrics \
                            aws-cloudwatch/aws-cloudwatch-metrics \
                            --namespace amazon-cloudwatch \
                            --create-namespace \
                            --set clusterName=${CLUSTER_NAME} \
                            --set region=${AWS_REGION} \
                            --wait --timeout 5m

                        # Deploy CloudWatch Logs (Fluent Bit)
                        helm upgrade --install aws-for-fluent-bit \
                            aws-cloudwatch/aws-for-fluent-bit \
                            --namespace amazon-cloudwatch \
                            --create-namespace \
                            --set cloudWatch.region=${AWS_REGION} \
                            --set cloudWatch.logGroupName=/roboshop/eks \
                            --wait --timeout 5m
                    """
                }
            }
        }
    } // end stages
    post {
        success {
            echo "Pipeline SUCCESS — Build #${BUILD_NUMBER}"
        }
        failure {
            echo "Pipeline FAILED — Build #${BUILD_NUMBER}"
        }
        always {
            cleanWs()
        }
    }
}
