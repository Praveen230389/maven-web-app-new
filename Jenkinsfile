pipeline {
    agent any
    
    tools {
        maven 'Maven-3.9.5' 
    }
    
    environment {
        AWS_DEFAULT_REGION = "ap-south-1"
        TARGET_SERVICE     = "maven-web-app"
    }
    
    stages {
        // 🎯 FIXED: वर्कस्पेस क्लीनअप को 'Checkout SCM' से भी पहले लाने के लिए 
        // इसे 'skipDefaultCheckout()' के साथ या बिल्कुल शुरुआत में रखना सबसे सही है, 
        // लेकिन सबसे आसान तरीका यह है कि हम इस स्टेज को ही हटा दें क्योंकि गिट खुद क्लीनअप कर देता है।
        
        stage('Maven Compile & Package') {
            steps {
                echo "Building Java Web Application (WAR) via Maven..."
                sh 'mvn clean package' // अब यहाँ pom.xml सुरक्षित मिलेगी!
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
                        
                        sed -i "s|image: REPLACE_WITH_AWS_ECR_URL/.*|image: \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:latest|g" ./k8s/*.yaml || true
                        sed -i "s|image: .*/${env.TARGET_SERVICE}:.*|image: \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:latest|g" ./k8s/*.yaml || true
                        
                        kubectl apply -f ./k8s/ -n production || true
                    """
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "Cleaning up local docker layers..."
                sh "docker image prune -f || true"
                // 🎯 FIXED: वर्कस्पेस को हमेशा बिल्ड के खत्म होने के बाद साफ करना चाहिए
                cleanWs()
            }
        }
    }
}
