pipeline {
    agent any
    
    tools {
        maven 'Maven-3.9.5' 
    }
    
    environment {
        AWS_DEFAULT_REGION = "ap-south-1"
        TARGET_SERVICE     = "maven-web-app"
        EKS_CLUSTER_NAME   = "ecommerce-cluster" // आपका असली क्लस्टर नाम
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
                        # 1. कंटेनर के अंदर ही कूबरनेटीस टूल्स (kubectl) को ऑफिशियली डाउनलोड करें
                        echo "Installing Kubectl client inside Jenkins container dynamically..."
                        curl -LO "https://k8s.io"
                        chmod +x ./kubectl
                        
                        # 2. क्रेडेंशियल्स का उपयोग करके कंटेनर के अंदर EKS Kubeconfig जनरेट करें
                        echo "Updating Kubeconfig using pipeline authenticated credentials..."
                        aws eks update-kubeconfig --region ${env.AWS_DEFAULT_REGION} --name ${env.EKS_CLUSTER_NAME}
                        
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                        LOCAL_ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
                        
                        # 3. 🎯 REAL WORKFLOW: आपकी रूट पर रखी k8s-deploy.yml में पुराना डॉकर हब इमेज हटाकर नया ECR इमेज एड्रेस डालना
                        echo "Modifying manifest k8s-deploy.yml with new ECR image tag..."
                        sed -i "s|image: praveen230389/.*|image: \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:${env.BUILD_NUMBER}|g" ./k8s-deploy.yml
                        
                        # 4. कूबरनेटीस क्लस्टर पर बदलावों को सीधे लागू करना
                        echo "Applying enterprise manifests to EKS Cluster..."
                        ./kubectl apply -f ./k8s-deploy.yml -n production
                        
                        # 5. रोलआउट का लाइव स्टेटस चेक करना (पक्का करने के लिए कि पॉड्स जिंदा हुए या नहीं)
                        echo "Verifying Rollout status on EKS..."
                        ./kubectl rollout status deployment/mavenwebappdeployment -n production --timeout=90s
                    """
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "[CLEANUP] Post-Build Actions: Pruning unused docker layers..."
                sh "docker image prune -f || true"
                cleanWs()
            }
        }
    }
}
