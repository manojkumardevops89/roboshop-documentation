pipeline {
  agent any

  stages {

    stage('Checkout') {
      steps {
        git 'https://github.com/manojkumardevops89/roboshop-documentation.git'
      }
    }

    stage('Build Services') {
      steps {
        sh '''
        cd services/frontend && npm install
        cd ../cart && npm install
        cd ../shipping && mvn clean package
        '''
      }
    }

    stage('SonarQube') {
      steps {
        sh 'sonar-scanner'
      }
    }

    stage('Docker Build') {
      steps {
        sh '''
        docker build -t frontend ./services/frontend
        docker build -t cart ./services/cart
        docker build -t shipping ./services/shipping
        '''
      }
    }

    stage('Trivy Scan') {
      steps {
        sh 'trivy image frontend'
      }
    }

    stage('Deploy Helm') {
      steps {
        sh 'helm upgrade --install roboshop ./helm'
      }
    }

    stage('ZAP Scan') {
      steps {
        sh 'zap-baseline.py -t http://roboshop-url'
      }
    }

    stage('Prowler') {
      steps {
        sh 'prowler aws'
      }
    }
  }
}
