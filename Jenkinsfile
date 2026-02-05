pipeline {
  agent {
    kubernetes {
      cloud 'kubernetes'
      defaultContainer 'kubectl'
      yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-sa
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
    tty: true
"""
    }
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        sh '''
          kubectl version --client=true
          kubectl apply -f deployment.yaml
          kubectl apply -f service.yaml
          kubectl rollout status deploy/demo-echo --timeout=120s
          kubectl get deploy demo-echo
          kubectl get svc demo-echo
        '''
      }
    }
  }
}

