pipeline {
  agent {
    kubernetes {
      cloud 'kubernetes'

      // 실패해도 pod를 남겨서 원인 확인 가능하게
      podRetention onFailure()

      // sh를 실행할 컨테이너를 확실히 지정
      defaultContainer 'kubectl'

      yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-sa
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
        // 컨테이너를 명시해서 durable-task가 확실히 여기서 sh를 돌리게 함
        container('kubectl') {
          sh '''
            set -eux
	    pwd 
	    ls -al

	    test -f deployment.yaml
	    test -f service.yaml

	    kubectl apply -n default -f deployment.yaml
	    kubectl apply -n default -f service.yaml
    	    kubectl rollout status -n default deployment/demo-echo --timeout=120s
	    kubectl get -n default deploy,svc,pods | head
          '''
        }
      }
    }
  }
}

