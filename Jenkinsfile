
pipeline {
    agent any
    environment {
        NEW_VERSION = '1.0.0'
    }
    stages {
        stage('build') {
            steps {
                echo 'building the application...'
                echo "building version ${NEW_VERSION} of the application..."
            }
        }
        stage('test') {
            steps {
                echo 'testing the application...'
            }
        }
        stage('deploy') {
            steps {
                echo 'deploying the application...'
            }
        }
    }
    post {
        always {
            echo 'Running post pipeline step...'
            withCredentials([usernamePassword(credentialsId: 'server-user-name', usernameVariable: 'USER', passwordVariable: 'PWD')]) {
                echo "Step was run by: ${USER} with password: ${PWD}"
            }
        }
        failure {
            echo 'Running post pipeline failure step...'
        }
    }
}
