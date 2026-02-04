pipeline {
  agent any

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main',
            url: 'https://github.com/youngbinjo/jenkins-k8s-demo.git'
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        sh '''
          kubectl apply -f deployment.yaml
          kubectl apply -f service.yaml
        '''
      }
    }
  }
}
