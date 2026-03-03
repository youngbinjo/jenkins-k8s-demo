#!/bin/bash
set -eux

# 0) 로그 남기기
exec > >(tee /var/log/user-data.log) 2>&1

apt-get update -y
apt-get install -y curl ca-certificates gnupg lsb-release unzip git

# 0-1. swap 생성 (OOM 방지 안전장치)
fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# 0-2) AWS CLI v2 설치
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
sudo ./aws/install

# 1) k3s 설치 (Traefik 비활성화 - Nginx Ingress 사용을 위해)
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable traefik

mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# 2) k3s API ready 대기
for i in {1..60}; do
  kubectl get nodes >/dev/null 2>&1 && break || true
  sleep 2
done

# 3) Helm 설치
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 4) Git 리포지토리 설정 ($$를 사용하여 테라폼 이스케이프 유지)
REPO_URL="https://github.com/youngbinjo/jenkins-k8s-demo.git"
WORKDIR="/opt/bootstrap/jenkins-k8s-demo"

rm -rf /opt/bootstrap
mkdir -p /opt/bootstrap
git clone "$${REPO_URL}" "$${WORKDIR}"

# Helm repo 등록
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo add jenkins https://charts.jenkins.io || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

# 5) Nginx Ingress Controller 설치
kubectl create namespace ingress-nginx || true
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.publishService.enabled=true

# 6) Jenkins 네임스페이스 및 RBAC 설정
kubectl create namespace jenkins || true

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: default
  namespace: jenkins
EOF

# 7) Jenkins 네임스페이스 및 설정 (Secret & ConfigMap)
kubectl create namespace jenkins || true

# [추가] 관리자 비밀번호 시크릿 생성 (password 키 이름 사용)
kubectl -n jenkins create secret generic jenkins-admin-pw \
  --from-literal=password="${JENKINS_PW}" \
  --dry-run=client -o yaml | kubectl apply -f -

# JCasC 설정 파일(ConfigMap) 생성
kubectl -n jenkins create configmap jenkins-casc \
  --from-file=jenkins.yaml="$${WORKDIR}/infra/jenkins-casc/jenkins.yaml" \
  --dry-run=client -o yaml | kubectl apply -f -

set +x
# GitHub 토큰 시크릿 생성
kubectl -n jenkins create secret generic github-token \
  --from-literal=GITHUB_TOKEN="${GITHUB_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -
set -x

# Jenkins Helm 설치 (최신 문법 적용)
helm upgrade --install jenkins jenkins/jenkins \
  -n jenkins \
  --set controller.admin.password="${JENKINS_PW}" \
  --set controller.javaOpts="-Xmx2048m -Duser.timezone=Asia/Seoul" \
  -f "$${WORKDIR}/infra/helm-values/jenkins-values.yaml"

# 8) Prometheus & Grafana 설치 (도메인 설정 포함)
kubectl create namespace monitoring || true

# 8) Prometheus & Grafana 설치
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=1d \
  --set alertmanager.enabled=false \
  --set grafana.adminPassword="${GRAFANA_PW}" \
  --set grafana."grafana\.ini".server.root_url="http://grafana.ybtest.pics/"

# 9) 호스트 기반 Ingress 설정 (ybtest.pics)

# (A) Grafana Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: "grafana.ybtest.pics"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
EOF

# (B) Jenkins Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins-ingress
  namespace: jenkins
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: "jenkins.ybtest.pics"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jenkins
            port:
              number: 8080
EOF

# (C) Prometheus Ingress (새로 추가된 도메인 설정)
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: "prometheus.ybtest.pics"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-kube-prometheus-prometheus
            port:
              number: 9090
EOF

# 10) Route 53 DNS 자동 갱신
MY_PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
TARGET_ZONE_ID="${ZONE_ID}"

cat <<EOF > update-dns.json
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "*.ybtest.pics",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [{ "Value": "$MY_PUBLIC_IP" }]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id $TARGET_ZONE_ID --change-batch file://update-dns.json

# 11) [추가] 슬랙 알림 자동화
# 본인의 실제 Webhook URL로 교체 필요
SLACK_WEBHOOK_URL="Your_slack_webhook_url_here" 

MESSAGE="🚀 *[인프라 복구 완료]* \n\n스팟 인스턴스 재생성 및 서비스 배포가 완료되었습니다. \n\n🌐 *접속 주소:* \n- Jenkins: http://jenkins.ybtest.pics \n- Grafana: http://grafana.ybtest.pics \n- Prometheus: http://prometheus.ybtest.pics"

curl -X POST -H 'Content-type: application/json' --data "{\"text\": \"$MESSAGE\"}" $SLACK_WEBHOOK_URL

echo "✅ GitOps bootstrap done"