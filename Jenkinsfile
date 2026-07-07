pipeline {
    agent any

    tools {
        maven 'Maven-3.9.5'
    }

    environment {
        AWS_DEFAULT_REGION = "ap-south-1"
        TARGET_SERVICE     = "maven-web-app"
        EKS_CLUSTER_NAME   = "ecommerce-cluster"
    }

    stages {

        stage('Maven Compile & Package') {
            steps {
                echo "[BUILD] Compiling Java Web Application (WAR) via Maven..."
                sh 'mvn clean package'
            }
        }

        stage('AWS ECR Login & Authenticate') {
            steps {
                echo "[AUTH] Authenticating and Logging into Amazon ECR Registry..."
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-credentials-id',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} \
                        | docker login \
                        --username AWS \
                        --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
                    '''
                }
            }
        }

        stage('Docker Image Build') {
            steps {
                echo "[DOCKER] Building Docker Image..."
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-credentials-id',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

                        LOCAL_ECR_URL=${ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com

                        docker build \
                        -t ${LOCAL_ECR_URL}/${TARGET_SERVICE}:${BUILD_NUMBER} .
                    '''
                }
            }
        }

        stage('Docker Push to ECR') {
            steps {
                echo "[PUSH] Uploading Image to Amazon ECR..."
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-credentials-id',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

                        LOCAL_ECR_URL=${ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com

                        docker push ${LOCAL_ECR_URL}/${TARGET_SERVICE}:${BUILD_NUMBER}
                    '''
                }
            }
        }

        stage('Deploy to Amazon EKS') {
            steps {

                echo "[DEPLOY] Deploying to Amazon EKS..."

                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-credentials-id',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {

                    sh '''

                    set -e

                    ##########################################
                    # Generate kubeconfig
                    ##########################################

                    aws eks update-kubeconfig \
                      --region ${AWS_DEFAULT_REGION} \
                      --name ${EKS_CLUSTER_NAME}

                    ##########################################
                    # Get Account ID
                    ##########################################

                    ACCOUNT_ID=$(aws sts get-caller-identity \
                    --query Account \
                    --output text)

                    LOCAL_ECR_URL=${ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com

                    ##########################################
                    # Update Deployment Manifest
                    ##########################################

                    sed -i \
                    "s|image: .*|image: ${LOCAL_ECR_URL}/${TARGET_SERVICE}:${BUILD_NUMBER}|g" \
                    k8s-deploy.yml

                    ##########################################
                    # Apply Deployment
                    ##########################################

                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v /var/lib/docker/volumes/jenkins_home/_data/.kube:/root/.kube \
                      -v /var/lib/docker/volumes/jenkins_home/_data/workspace/mavenapp:/apps \
                      -w /apps \
                      bitnami/kubectl:latest \
                      kubectl apply -f k8s-deploy.yml -n production

                    ##########################################
                    # Wait for Rollout
                    ##########################################

                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v /var/lib/docker/volumes/jenkins_home/_data/.kube:/root/.kube \
                      -v /var/lib/docker/volumes/jenkins_home/_data/workspace/mavenapp:/apps \
                      -w /apps \
                      bitnami/kubectl:latest \
                      kubectl rollout status deployment/mavenwebappdeployment \
                      -n production \
                      --timeout=180s

                    '''
                }
            }
        }

    }

    post {

        always {

            script {

                echo "[CLEANUP] Cleaning Workspace..."

                sh 'docker image prune -f || true'

                cleanWs()

            }

        }

    }

}
