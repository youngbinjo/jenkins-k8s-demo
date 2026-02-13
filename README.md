📦 Jenkins + Kubernetes 기반 CI/CD 파이프라인 구축
프로젝트 개요

GitHub에 코드를 push하면 Jenkins 파이프라인이 자동으로 실행되고,
Kubernetes 클러스터에 애플리케이션이 자동 배포되는
CI/CD 환경을 직접 구축한 프로젝트이다.

아키텍처 구성
GitHub
  ↓ (push)
Jenkins Pipeline
  ↓
Kubernetes Agent Pod
  ↓
kubectl apply
  ↓
Deployment 롤아웃

사용 기술 스택
영역	기술
Cloud	AWS EC2
Container Orchestration	k3s (Kubernetes)
CI/CD	Jenkins
SCM	GitHub
Deployment	kubectl
IaC (일부)	Terraform (인프라 구성 단계)
전체 실행 흐름
1. GitHub 저장소에 코드 push
git add .
git commit -m "update deployment"
git push

2. Jenkins 파이프라인 자동 실행

Jenkins가 GitHub 저장소를 감지하여 파이프라인 실행

3. Kubernetes Agent Pod 생성

Jenkins가 Kubernetes에 임시 에이전트 Pod 생성

k8s-deploy-pipeline-xxxxx

4. 애플리케이션 배포

Pipeline 내부에서 실행:

kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl rollout status deploy/demo-echo

5. 배포 결과 확인
kubectl get pods


출력 예시:

demo-echo-xxxxx   1/1   Running

Jenkinsfile (핵심 파이프라인)
pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-sa
  containers:
  - name: kubectl
    image: bitnami/kubectl:1.30
    command:
    - cat
    tty: true
"""
    }
  }

  stages {
    stage('Deploy to Kubernetes') {
      steps {
        container('kubectl') {
          sh '''
            set -eux
            kubectl apply -f deployment.yaml
            kubectl apply -f service.yaml
            kubectl rollout status deploy/demo-echo --timeout=120s
          '''
        }
      }
    }
  }
}

트러블슈팅 요약
1. Jenkins에서 kubectl 명령어 실행 실패

에러

kubectl: not found


원인

Jenkins 에이전트 컨테이너에 kubectl 미설치

해결

kubectl 이미지 기반 Kubernetes agent 사용

2. Kubernetes API 접근 권한 오류

에러

User "system:serviceaccount:jenkins:jenkins-sa" cannot get resource


원인

Jenkins ServiceAccount 권한 부족

해결

RoleBinding 추가

3. Ingress 404 및 NodePort 연결 실패

원인

iptables 규칙 및 포트 포워딩 충돌

해결

NodePort 및 NAT 규칙 재구성

nginx 리버스 프록시 구성

프로젝트 결과
구축 완료 항목

k3s 기반 Kubernetes 클러스터 구축

Jenkins 설치 및 Kubernetes 연동

GitHub → Jenkins → Kubernetes 자동 배포

Kubernetes Agent 기반 파이프라인 구성

향후 개선 계획

Prometheus + Grafana 모니터링 추가

Terraform 기반 전체 인프라 코드화

Jenkins를 Ingress로 외부 노출
# webhook test 2026-02-13T05:02:52+00:00
# webhook test after restart 2026-02-13T06:21:44+00:00
