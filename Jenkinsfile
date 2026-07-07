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
                        # 1. 🎯 FIXED: कूबरनेटीस की ऑफिशियल बाइनरी स्टोरेज से सीधे kubectl डाउनलोड करना
                        echo "Downloading exact stable Kubectl binary..."
                        curl -LO "https://k8s.io"
                        chmod +x ./kubectl
                        
                        # 2. क्रेडेंशियल्स का उपयोग करके कंटेनर के अंदर EKS Kubeconfig जनरेट करें
                        echo "Updating Kubeconfig using pipeline authenticated credentials..."
                        aws eks update-kubeconfig --region ${env.AWS_DEFAULT_REGION} --name ${env.EKS_CLUSTER_NAME}
                        
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                        LOCAL_ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
                        
                        # 3. REAL WORKFLOW: आपकी k8s-deploy.yml में नया ECR इमेज टैग डालना
                        echo "Modifying manifest k8s-deploy.yml with new ECR image tag..."
                        sed -i "s|image: praveen230389/.*|image: \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:${env.BUILD_NUMBER}|g" ./k8s-deploy.yml
                        
                        # 4. कूबरनेटीस क्लस्टर पर बदलावों को सीधे लागू करना
                        echo "Applying enterprise manifests to EKS Cluster..."
                        ./kubectl apply -f ./k8s-deploy.yml -n production
                        
                        # 5. रोलआउट का लाइव स्टेटस चेक करना
                        echo "Verifying Rollout status on EKS..."
                        ./kubectl rollout status deployment/mavenwebappdeployment -n production --timeout=90s
                    """
                } // FIXED: withCredentials ब्लॉक बंद किया
            } // FIXED: steps ब्लॉक बंद किया
        } // FIXED: stage ब्लॉक बंद किया
    } // FIXED: stages ब्लॉक बंद किया
    
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
