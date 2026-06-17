pipeline {
    agent any

    environment {
        AWS_REGION = "ap-south-1"
        AWS_ACCOUNT_ID = "262252231763"
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        CLUSTER_NAME = "abhi-ejaz-cluster"
        K8S_NAMESPACE = "abhi-ejaz"
        SONAR_HOST_URL = "http://localhost:9000"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('SonarQube Scan') {
            steps {
                withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                    sonar-scanner \
                    -Dsonar.projectKey=abhiejaz-shop \
                    -Dsonar.projectName=abhiejaz-shop \
                    -Dsonar.sources=services \
                    -Dsonar.exclusions=**/node_modules/**,**/.git/** \
                    -Dsonar.host.url=$SONAR_HOST_URL \
                    -Dsonar.token=$SONAR_TOKEN
                    '''
                }
            }
        }

        stage('AWS Identity Check') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                    aws sts get-caller-identity
                    '''
                }
            }
        }

        stage('ECR Login') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
                    '''
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
                    kubectl get nodes
                    kubectl get pods -n $K8S_NAMESPACE
                    '''
                }
            }
        }

        stage('ArgoCD Login and Sync') {
            steps {
                withCredentials([string(credentialsId: 'argocd-password', variable: 'ARGO_PASS')]) {
                    sh '''
                    argocd login localhost:8081 --username admin --password "$ARGO_PASS" --insecure
                    argocd app sync abhi-ejaz-shop
                    argocd app wait abhi-ejaz-shop --health --timeout 300
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully'
        }
        failure {
            echo 'Pipeline failed'
        }
    }
}
