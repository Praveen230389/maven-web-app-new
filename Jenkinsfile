pipeline {
    agent any
    
    tools {
        maven 'maven-3.9.5' // पक्का करें कि आपके जेनकिंस UI में मैवेन का यह नाम सेव हो
    }
    
    environment {
        AWS_DEFAULT_REGION = "ap-south-1"
        TARGET_SERVICE     = "maven-web-app"
    }
    
    stages {
        stage('Workspace Clean & SCM') {
            steps {
                cleanWs()
            }
        }
        
        stage('Maven Compile & Package') {
            steps {
                echo "Building Java WAR file using Maven..."
                sh 'mvn clean package' //
            }
        }
        
        stage('AWS ECR Login') {
            steps {
                echo "Logging into Amazon ECR..."
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
                echo "Building production Docker image for Java App..."
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
                echo "Pushing image to Amazon ECR..."
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
                echo "Deploying to Amazon EKS..."
                withCredentials([usernamePassword(credentialsId: 'aws-credentials-id', 
                                                 usernameVariable: 'AWS_ACCESS_KEY_ID', 
                                                 passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh """
                        ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                        LOCAL_ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${env.AWS_DEFAULT_REGION}.amazonaws.com"
                        
                        sed -i "s|image: REPLACE_WITH_AWS_ECR_URL/.*|image: \${LOCAL_ECR_URL}/${env.TARGET_SERVICE}:latest|g" ./k8s/*.yaml || true
                        
                        kubectl apply -f ./k8s/ -n production || true
                    """
                }
            }
        }
    }
}
