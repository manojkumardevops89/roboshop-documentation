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
        DT_TENANT    = credentials('dynatrace-tenant-url')
        DT_TOKEN     = credentials('dynatrace-api-token')
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
                    # Node.js services
                    for svc in frontend cart user payment; do
                        cd services/$svc && npm install && cd -
                    done

                    # Java service
                    cd services/shipping && mvn clean package -q && cd -

                    # Go services
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
                        # ECR login
                        aws ecr get-login-password --region ${AWS_REGION} \
                          | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                        # Build all services
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

        // ── 11. DYNATRACE ─────────────────────────────────────────────────
        stage('Dynatrace') {
            steps {
                sh """
                    helm repo add dynatrace \
                        https://raw.githubusercontent.com/Dynatrace/dynatrace-operator/main/config/helm/repos/stable \
                        2>/dev/null || true
                    helm repo update
                    helm upgrade --install dynatrace-operator \
                        dynatrace/dynatrace-operator \
                        --namespace dynatrace --create-namespace \
                        --set apiUrl=${DT_TENANT}/api \
                        --set apiToken=${DT_TOKEN} \
                        --wait --timeout 5m
                """
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
