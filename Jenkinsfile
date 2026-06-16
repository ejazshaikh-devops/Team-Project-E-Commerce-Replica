pipeline {
    agent any

    environment {
        AWS_REGION = "ap-south-1"
        AWS_ACCOUNT_ID = "262252231763"
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ECR_PREFIX = "abhi-ejaz"
        K8S_NAMESPACE = "abhi-ejaz"
        CLUSTER_NAME = "abhi-ejaz-cluster"

        SONAR_HOST_URL = "http://localhost:9000"
        ARGOCD_SERVER = "localhost:8081"
        ARGOCD_APP = "abhi-ejaz-shop"
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
                      -Dsonar.projectKey=shopsphere \
                      -Dsonar.projectName=ShopSphere \
                      -Dsonar.sources=. \
                      -Dsonar.exclusions=**/node_modules/**,**/.git/**,**/terraform/.terraform/** \
                      -Dsonar.host.url=$SONAR_HOST_URL \
                      -Dsonar.token=$SONAR_TOKEN
                    '''
                }
            }
        }

        stage('ECR Login') {
            steps {
                sh '''
                aws ecr get-login-password --region $AWS_REGION | \
                docker login --username AWS --password-stdin $ECR_REGISTRY
                '''
            }
        }

        stage('Build and Push Images') {
            steps {
                sh '''
                BUILD_TAG=${BUILD_NUMBER}

                for svc in product-service cart-service order-service user-service api-gateway; do
                  docker build -f services/$svc/Dockerfile -t $svc:$BUILD_TAG .
                  docker tag $svc:$BUILD_TAG $ECR_REGISTRY/$ECR_PREFIX/$svc:$BUILD_TAG
                  docker tag $svc:$BUILD_TAG $ECR_REGISTRY/$ECR_PREFIX/$svc:latest
                  docker push $ECR_REGISTRY/$ECR_PREFIX/$svc:$BUILD_TAG
                  docker push $ECR_REGISTRY/$ECR_PREFIX/$svc:latest
                done
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

                kubectl rollout restart deployment product-service cart-service order-service user-service api-gateway -n $K8S_NAMESPACE

                kubectl rollout status deployment/product-service -n $K8S_NAMESPACE
                kubectl rollout status deployment/cart-service -n $K8S_NAMESPACE
                kubectl rollout status deployment/order-service -n $K8S_NAMESPACE
                kubectl rollout status deployment/user-service -n $K8S_NAMESPACE
                kubectl rollout status deployment/api-gateway -n $K8S_NAMESPACE
                '''
            }
        }

        stage('ArgoCD Sync') {
            steps {
                withCredentials([
                    string(credentialsId: 'argocd-username', variable: 'ARGOCD_USERNAME'),
                    string(credentialsId: 'argocd-password', variable: 'ARGOCD_PASSWORD')
                ]) {
                    sh '''
                    argocd login $ARGOCD_SERVER \
                      --username $ARGOCD_USERNAME \
                      --password $ARGOCD_PASSWORD \
                      --insecure

                    argocd app sync $ARGOCD_APP
                    argocd app wait $ARGOCD_APP --health --timeout 300
                    '''
                }
            }
        }

        stage('Verify') {
            steps {
                sh '''
                kubectl get pods -n $K8S_NAMESPACE
                kubectl get ingress -n $K8S_NAMESPACE
                '''
            }
        }
    }

    post {
        success {
            echo "ShopSphere CI/CD with SonarQube and ArgoCD completed successfully."
        }
        failure {
            echo "Pipeline failed. Check console output."
        }
    }
}
