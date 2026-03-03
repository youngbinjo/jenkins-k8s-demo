pipeline {
    agent {
        kubernetes {
            cloud 'kubernetes'

            // 실패해도 pod를 남겨서 원인 확인 가능하게 설정
            podRetention onFailure()

            // sh를 실행할 기본 컨테이너 지정
            defaultContainer 'kubectl'

            yaml """
apiVersion: v1
kind: Pod
spec:
  # 이전 에러 해결을 위해 default 계정 사용 (또는 jenkins-sa 생성 필요)
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
            steps {
                // GitHub 리포지토리 코드를 가져옵니다.
                checkout scm
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh '''
                        set -eux
                        
                        # 1. 파일 위치 정의 (알려주신 경로)
                        YAML_PATH="infra/k8s/demo-echo"
                        
                        # 2. 파일 존재 여부 확인 (디버깅용)
                        echo "Checking files in ${YAML_PATH}..."
                        ls -al ${YAML_PATH}

                        # 3. 배포 실행 (경로를 명시하여 실행)
                        kubectl apply -n default -f ${YAML_PATH}/deployment.yaml
                        kubectl apply -n default -f ${YAML_PATH}/service.yaml

                        # 4. 배포 결과 확인
                        kubectl rollout status -n default deployment/demo-echo --timeout=120s
                        kubectl get -n default deploy,svc,pods | grep demo-echo
                    '''
                }
            }
        }
    }
}
