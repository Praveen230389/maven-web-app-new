pipeline {
    agent any
    
    tools {
        // पक्का करें कि आपके जेनकिंस UI (Global Tool Configuration) में Maven का नाम यही हो
        maven 'Maven-3.9.5' 
    }
    
    environment {
        AWS_DEFAULT_REGION = "ap-south-1"
        TARGET_SERVICE     = "maven-web-app" // आपकी इस इमेज का नाम ECR के लिए
    }
    
    stages {
        stage('Workspace Clean') {
            steps {
                echo "Cleaning up the old workspace cache..."
                cleanWs()
            }
        }
        
        // 🎯 FIXED: यहाँ दोबारा मैन्युअल गिट क्लोन करने की कोई जरूरत नहीं है, 
        // जेनकिंस की डिफ़ॉल्ट चेकआउट स्टेज ही सब कुछ सही पाथ पर डाउनलोड रखेगी।
        
        stage('Maven Compile & Package') {
            steps {
                echo "Building Java Web Application (WAR) via Maven..."
                sh 'mvn clean package'
            }
        }
        
        stage('AWS ECR Login') {
            steps {
                echo "Logging into Amazon ECR Registry..."
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
                echo "Building production Docker image using repo Dockerfile..."
                withCredentials([usernamePassword(credentialsId: 'aws-credentials-id', 
                                                 usernameVariable: 'AWS_ACCESS_KEY_ID', 
                                                 passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh """
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                        LOCAL_ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
                        
                        # सीधे रूट पर रखी तुम्हारी असली Dockerfile से इमेज बिल्ड होगी
                        docker build -t \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:latest .
                    """
                }
            }
        }
        
        stage('Docker Push Image') {
            steps {
                echo "Pushing verified image to Amazon ECR Repository..."
                withCredentials([usernamePassword(credentialsId: 'aws-credentials-id', 
                                                 usernameVariable: 'AWS_ACCESS_KEY_ID', 
                                                 passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh """
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                        LOCAL_ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
                        
                        docker push \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:latest
                    """
                }
            }
        }
        
        stage('Kubernetes Deployment') {
            steps {
                echo "Deploying Java App to Amazon EKS Cluster..."
                withCredentials([usernamePassword(credentialsId: 'aws-credentials-id', 
                                                 usernameVariable: 'AWS_ACCESS_KEY_ID', 
                                                 passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh """
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                        LOCAL_ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
                        
                        echo "Replacing Image Tag inside your k8s folder files..."
                        sed -i "s|image: REPLACE_WITH_AWS_ECR_URL/.*|image: \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:latest|g" ./k8s/*.yaml || true
                        sed -i "s|image: .*/${env.TARGET_SERVICE}:.*|image: \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:latest|g" ./k8s/*.yaml || true
                        
                        echo "Applying manifests to EKS cluster..."
                        kubectl apply -f ./k8s/ -n production || true
                    """
                }
            }
        }
    }
    
    post {
        always {
            script {
                sh "docker image prune -f || true"
            }
        }
    }
}
