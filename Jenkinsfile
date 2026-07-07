pipeline {
    agent any
    
    tools {
        // पक्का करें कि आपके जेनकिंस UI (Global Tool Configuration) में Maven का नाम यही सेट हो
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
                withCredentials([usernamePassword(credentialsId: 'aws-credentials-id', 
                                                 usernameVariable: 'AWS_ACCESS_KEY_ID', 
                                                 passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh """
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                        aws ecr get-login-password --region ${env.AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin \${ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com
                    """
                }
            }
        }
        
        stage('Docker Image Build') {
            steps {
                echo "[DOCKER] Packaging application into Docker image..."
                withCredentials([usernamePassword(credentialsId: 'aws-credentials-id', 
                                                 usernameVariable: 'AWS_ACCESS_KEY_ID', 
                                                 passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh """
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                        LOCAL_ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
                        docker build -t \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:${env.BUILD_NUMBER} .
                    """
                }
            }
        }
        
        stage('Docker Push to ECR') {
            steps {
                echo "[PUSH] Uploading build version ${env.BUILD_NUMBER} to AWS ECR..."
                withCredentials([usernamePassword(credentialsId: 'aws-credentials-id', 
                                                 usernameVariable: 'AWS_ACCESS_KEY_ID', 
                                                 passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh """
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                        LOCAL_ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
                        docker push \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:${env.BUILD_NUMBER}
                    """
                }
            }
        }
        
        stage('Kubernetes EKS Deployment') {
            steps {
                echo "[DEPLOY] Dynamically configuring and deploying to Amazon EKS Cluster..."
                withCredentials([usernamePassword(credentialsId: 'aws-credentials-id', 
                                                 usernameVariable: 'AWS_ACCESS_KEY_ID', 
                                                 passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh """
                        # 1. क्रेडेंशियल्स का उपयोग करके कंटेनर के अंदर EKS Kubeconfig जनरेट करें
                        aws eks update-kubeconfig --region ${env.AWS_DEFAULT_REGION} --name ${env.EKS_CLUSTER_NAME}
                        
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                        LOCAL_ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
                        
                        echo "Modifying manifest k8s-deploy.yml with new ECR image tag..."
                        sed -i "s|image: praveen230389/.*|image: \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:${env.BUILD_NUMBER}|g" ./k8s-deploy.yml
                        
                        echo "Applying enterprise manifests to EKS Cluster via Official Public Tooling..."
                        # 🎯 FIXED: वर्कस्पेस माउंट (-v) और वर्किंग डायरेक्टरी (-w) को जोड़ दिया गया है ताकि k8s-deploy.yml 100% डिटेक्ट हो जाए
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v /var/jenkins_home/.kube:/root/.kube -v \$(pwd):/apps -w /apps bitnami/kubectl:latest apply -f ./k8s-deploy.yml -n production
                        
                        echo "Checking live roll-out status directly from cluster..."
                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v /var/jenkins_home/.kube:/root/.kube -v \$(pwd):/apps -w /apps bitnami/kubectl:latest rollout status deployment/mavenwebappdeployment -n production --timeout=90s
                    """
                } 
            } 
        } 
    } 
}
