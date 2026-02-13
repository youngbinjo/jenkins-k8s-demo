pipeline {
  agent {
    kubernetes {
      cloud 'kubernetes'
      podRetention onFailure()
      defaultContainer 'kubectl'

      yaml """
apiVersion: v1
kind: Pod
spec:
  # 이 부분을 jenkins-sa에서 default로 변경합니다.
  serviceAccountName: default 
  containers:
  - name: kubectl
    image: dtzar/helm-kubectl:3.15.3
    command: ["cat"]
    tty: true
    securityContext:
      runAsUser: 0
      runAsGroup: 0
"""
    }
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Deploy to Kubernetes') {
      steps {
        container('kubectl') {
          sh '''
            set -eux
            # 파일 경로 확인 (k8s/ 폴더 안에 있다면 경로 수정 필요)
            # 만약 파일이 k8s 폴더 안에 있다면: cd k8s
            
            kubectl apply -n default -f deployment.yaml
            kubectl apply -n default -f service.yaml
            kubectl rollout status -n default deployment/demo-echo --timeout=120s
          '''
        }
      }
    }
  }
}
