# 🚀 AWS & K8s 기반 비용 최적화 CI/CD 및 모니터링 구축

> **AWS Spot Instance**와 **K3s**를 활용하여 최소 비용으로 구축한 기업급 인프라 자동화 및 관측성(Observability) 프로젝트입니다.

---

## 🏗 아키텍처 (Architecture)



* **Infrastructure**: Terraform → AWS EC2 (Spot) → K3s
* **CI/CD**: GitHub → Webhook → Jenkins Pipeline → K8s Deployment
* **Observability**: K8s Metrics → Prometheus → Grafana → Slack Alert

---

## 🛠 기술 스택 (Tech Stack)

| 구분 | 기술 | 상세 내용 |
| :--- | :--- | :--- |
| **Cloud** | **AWS** | EC2 Spot Instance, VPC, Security Group |
| **IaC** | **Terraform** | 인프라 프로비저닝 자동화 |
| **Orchestration** | **K3s** | 경량화 Kubernetes 클러스터 운영 |
| **CI/CD** | **Jenkins** | Docker 기반 Pipeline 배포 자동화 |
| **Monitoring** | **Prometheus** | 시계열 메트릭 데이터 수집 |
| **Visualization** | **Grafana** | 실시간 데이터 시각화 및 알림 설정 |
| **Notification** | **Slack** | Incoming Webhooks 기반 장애 전파 |

---

## 🌟 핵심 구현 내용

### 1️⃣ 인프라 자동화 및 비용 최적화
* **비용 절감**: AWS 스팟 인스턴스 도입으로 인프라 운영 비용 약 **70% 절감**.
* **복구 탄력성**: 인스턴스 회수 시 **Terraform**과 **User_data**를 통해 5분 이내 자동 복구 체계 구축.

### 2️⃣ 관측성(Observability) 및 알림 체계
* **실시간 모니터링**: Prometheus를 데이터 소스로 하여 클러스터 리소스 상태 시각화.
* **장애 대응**: 가용 메모리 **10% 미만** 도달 시 즉시 **Slack 알림** 발송 규칙(Alert Rule) 적용.

### 3️⃣ 리소스 최적화 (Troubleshooting)
* **OOM 문제 해결**: Jenkins의 과도한 자원 점유를 발견하고 **JVM Heap Size(`-Xmx2048m`)** 제한을 통해 시스템 안정성 확보.

---

## 🔍 주요 트러블슈팅 경험

### ✅ 문제 1: 스팟 인스턴스 재시작 후 접속 불가 (503/404 Error)
* **원인**: 인프라 재구성 시 Ingress의 백엔드 서비스 포트 매칭 오류 발생.
* **해결**: `kubectl` 엔드포인트 검증 후 Ingress 설정을 실제 서비스 포트(9090)로 수정하여 정상화.

### ✅ 문제 2: Jenkins 파이프라인 권한 및 실행 오류
* **원인**: Jenkins ServiceAccount의 권한 부족 및 에이전트 내 `kubectl` 미설치.
* **해결**: **RoleBinding** 설정 및 **Kubernetes Pod Agent**를 활용한 컨테이너 기반 빌드 환경 구축.

---

## 📈 향후 개선 계획
- [ ] **Loki** 기반의 로그 통합 관리 시스템 구축
- [ ] **ArgoCD** 도입을 통한 GitOps 배포 프로세스 전환
- [ ] **Cert-Manager**를 활용한 HTTPS 보안 강화

---

## 💡 한 줄 소감
> "제한된 자원 내에서 최적의 성능을 끌어내기 위한 리소스 튜닝과 장애 대응 프로세스의 중요성을 경험한 프로젝트입니다."
