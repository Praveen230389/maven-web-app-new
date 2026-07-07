pipeline {
    agent any
    
    tools{
        maven 'Maven-3.9.9'
    }
    stages {
        stage('clone') {
            steps {
              git 'https://github.com/Praveen230389/maven-web-app-new.git'
            }
        }
        stage('build'){
            steps{
                 sh 'mvn clean package'
            }
        }
        stage('docker image'){
            steps {
                sh 'docker build -t ashokit/mavenwebapp .'
            }
        }
        stage('k8s deploy'){
            steps{
               sh 'kubectl apply -f k8s-deploy.yml'
            }
        }
    }
}
