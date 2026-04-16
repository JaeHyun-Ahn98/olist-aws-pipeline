# 🛒 Olist AWS Pipeline

> 브라질 이커머스 데이터 기반 AWS 엔드투엔드 배치 파이프라인

[![Python](https://img.shields.io/badge/Python-3.10-blue)](https://python.org)
[![AWS Glue](https://img.shields.io/badge/AWS_Glue-ETL-orange)](https://aws.amazon.com/glue)
[![Redshift](https://img.shields.io/badge/Amazon_Redshift-DWH-red)](https://aws.amazon.com/redshift)
[![Airflow](https://img.shields.io/badge/Airflow-2.9.0-green)](https://airflow.apache.org)
[![dbt](https://img.shields.io/badge/dbt-1.9.0-orange)](https://getdbt.com)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-purple)](https://terraform.io)
[![CI](https://github.com/JaeHyun-Ahn98/olist-aws-pipeline/actions/workflows/dbt_test.yml/badge.svg)](https://github.com/JaeHyun-Ahn98/olist-aws-pipeline/actions)

---

## 📊 대시보드

👉 **[Superset Dashboard 보기](http://3.39.103.198:8088/superset/dashboard/1/)**

---

## 🏗️ 아키텍처

![Architecture](docs/architecture.PNG)

```
Local CSV (Olist 9개 테이블)
 └→ Python (S3 업로드)
      └→ Amazon S3 (Data Lake)
           └→ AWS Glue ETL (S3 → Redshift 적재 · PySpark)
                └→ Amazon Redshift (Data Warehouse)
                     └→ dbt Core (staging → marts 변환)
                          └→ Apache Superset (시각화 · EC2 배포)

오케스트레이션: Apache Airflow (@daily · Docker · DockerOperator)
CI/CD:         GitHub Actions (push 시 dbt test 자동 실행)
인프라:         Terraform (S3 · Redshift · EC2 IaC 관리)
```

---

## 🎯 프로젝트 배경 & 목적

[첫 번째 프로젝트 (GCP 기반)](https://github.com/JaeHyun-Ahn98/mes-sensor-pipeline)에서 아쉬웠던 점 3가지를 이번 프로젝트에서 직접 보완했습니다.

| 1번 프로젝트 아쉬운 점 | 2번 프로젝트 해결 방법 |
|---|---|
| 데이터 품질 자동 검증 없음 | dbt test 10개 + GitHub Actions CI/CD |
| 파이프라인 실패 알림 없음 | Airflow Gmail SMTP 이메일 알림 |
| 대시보드 로컬에서만 접근 가능 | EC2에 Superset 직접 배포 → 외부 URL |

GCP → AWS로 클라우드를 전환해 **멀티클라우드 경험**을 확보했습니다.

---

## 💡 기술 선택 이유

| 기술 | 선택한 이유 |
|---|---|
| **AWS Glue** | S3 데이터를 Redshift로 옮기는 서버리스 ETL. PySpark 문법 그대로 사용 가능하여 1번 프로젝트 경험 재활용 |
| **Amazon Redshift** | 컬럼형 DWH로 대용량 분석 쿼리 최적화. AWS 생태계와 자연스러운 연동 |
| **dbt Core** | SQL로 staging → marts 계층 변환. 테스트 기능으로 데이터 품질 자동 검증 |
| **Airflow (Docker)** | 전체 파이프라인 @daily 자동화. DockerOperator로 dbt 의존성 격리 해결 |
| **DockerOperator** | dbt-redshift를 Airflow 이미지에 직접 설치 시 의존성 충돌 발생 → 공식 이미지로 격리 |
| **GitHub Actions** | push 시 dbt test 자동 실행. GitHub Secrets로 Redshift 접속 정보 안전하게 관리 |
| **Superset (EC2)** | 오픈소스 BI 툴. EC2에 직접 배포해 외부에서 접근 가능한 URL 생성 |
| **Terraform** | S3, Redshift, EC2를 코드로 관리. 재현 가능한 인프라 구성 |

---

## 📁 데이터셋

- **출처:** [Brazilian E-Commerce Public Dataset by Olist (Kaggle)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **규모:** 주문 10만 건 이상 · 9개 테이블 · 2016~2018년
- **주요 테이블:** orders, customers, order_items, order_payments, order_reviews, products, sellers, geolocation, category_translation

---

## 🔍 EDA 핵심 발견

### 1. RFM 분석 한계 인지 및 방향 수정

전체 고객 93,400명 중 **97%가 1회 구매 고객**임을 EDA에서 발견. Frequency 지표가 의미없는 상황을 파악하고 Recency와 Monetary 중심으로 고객 세그먼트 분류 방향 수정. 브라질 이커머스 초기 시장(2016~2018)의 낮은 재구매율이 원인임을 확인.

### 2. CSV 파싱 오류 발견 (dbt test)

dbt test 실행 중 `review_score` 컬럼에 날짜값이 혼재됨을 발견. review_comment_message에 쉼표 포함 시 Glue ETL이 컬럼을 밀려서 적재하는 문제. staging 레이어에서 `WHERE review_score ~ '^[1-5]$'` 필터로 처리. **테스트를 약하게 만드는 대신 upstream에서 처리하는 실무적 접근 채택.**

---

## 🔥 핵심 문제 해결 경험

### 1. dbt + Airflow 의존성 충돌 → DockerOperator로 분리

Airflow 컨테이너에 `dbt-redshift` 직접 설치 시 의존성 충돌 발생. dbt 공식 이미지(`ghcr.io/dbt-labs/dbt-redshift:1.9.0`)를 DockerOperator로 실행해 완전히 격리. 각 도구의 공식 이미지를 활용하는 방식의 효용성 확인.

### 2. Airflow Jinja 템플릿 vs 환경변수 혼용

DockerOperator environment에 `{{ var.value.AWS_ACCESS_KEY_ID }}` Jinja 방식 사용 시 `KeyError` 발생. docker-compose.yml에서 환경변수가 이미 주입되어 있으므로 `os.environ.get()` 방식으로 변경.

### 3. Superset Redshift 드라이버 인식 실패

Superset 컨테이너가 `/app/.venv/bin/python`을 사용하는 자체 가상환경을 보유해 일반 `pip install`로는 설치되지 않는 문제. root 권한으로 `ensurepip` 실행 후 venv의 Python으로 직접 설치해 해결.

### 4. Glue 중복 적재 → dbt staging에서 멱등성 확보

Glue Job 재실행 시 raw 테이블에 동일 데이터가 중복 적재되는 문제. 모든 staging 모델에 `SELECT DISTINCT` 추가로 멱등성(idempotency) 확보. raw 레이어는 원본 그대로 유지하고 staging에서 품질을 보정하는 레이어 역할 분리 원칙 적용.

---

## 📂 프로젝트 구조

```
olist-aws-pipeline/
├── infra/
│   ├── terraform/                      # AWS 리소스 (S3, Redshift, EC2, VPC)
│   └── docker/
│       ├── docker-compose.yml          # Airflow (webserver, scheduler, init, postgres)
│       ├── docker-compose.superset.yml # Superset
│       ├── Dockerfile.airflow          # boto3, airflow-providers-docker
│       └── Dockerfile.superset         # psycopg2, sqlalchemy-redshift
├── pipeline/
│   ├── extract/
│   │   └── upload_to_s3.py             # Local CSV → S3 업로드
│   ├── glue/
│   │   └── etl_olist.py                # S3 → Redshift ETL (AWS Glue Job)
│   └── airflow/dags/
│       └── olist_pipeline_dag.py       # DAG: upload_s3 → glue_job → run_dbt
├── transform/
│   └── olist_pipeline/
│       └── models/
│           ├── staging/                # 8개 view (원본 정제 · 중복 제거)
│           └── marts/                  # 4개 table (분석용 최종 테이블)
├── notebooks/                          # EDA Jupyter 노트북
├── .github/workflows/
│   └── dbt_test.yml                    # GitHub Actions CI (push → dbt test)
└── docs/
    └── architecture.png
```

---

## 🔧 dbt 모델 구조

### Staging (8개 View)

| 모델 | 주요 처리 |
|---|---|
| stg_orders | 컬럼명 정규화, 타입 변환, 중복 제거 |
| stg_customers | 중복 제거 |
| stg_order_items | 중복 제거 |
| stg_order_payments | 중복 제거 |
| stg_order_reviews | CSV 파싱 오류 필터링 (`review_score ~ '^[1-5]$'`) |
| stg_products | 중복 제거 |
| stg_sellers | 중복 제거 |
| stg_category_translation | 중복 제거 |

### Marts (4개 Table)

| 모델 | 설명 |
|---|---|
| mart_orders | 주문 + 결제 + 배송 통합 분석 테이블 |
| mart_rfm | 고객별 Recency · Frequency · Monetary 지표 |
| mart_customer_segments | VIP · Active · At-Risk · Lost 고객 세그먼트 분류 |
| mart_delivery_analysis | 실제 배송일 vs 예상 배송일 · 지연 여부 분석 |

---

## 📊 주요 인사이트

- **고객 세그먼트:** VIP 4,257명(avg $923) · Active 36,126명 · At-Risk 33,054명 · Lost 19,913명
- **결제 수단:** credit_card 74% · boleto(브라질 전통 결제) 19% · voucher 5%
- **1회 구매 비율:** 전체 93,400명 중 97% (브라질 이커머스 초기 시장 특성)
- **배송 지연:** SP(상파울루), RJ(리우데자네이루) 지역 최다 지연 발생

---

## ⚙️ 실행 방법

### 1. 사전 준비

```bash
git clone https://github.com/JaeHyun-Ahn98/olist-aws-pipeline.git
cd olist-aws-pipeline
python -m venv venv
venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

### 2. AWS 인프라 생성

```bash
cd infra/terraform
terraform init
terraform apply
```

### 3. 환경변수 설정

```bash
# infra/docker/.env 파일 생성
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=ap-northeast-2
GMAIL_USER=your-email@gmail.com
GMAIL_APP_PASSWORD=your-app-password
```

### 4. Airflow 실행

```bash
cd infra/docker
docker compose up airflow-init   # "User admin created" 확인 후 Ctrl+C
docker compose up -d
# localhost:8080 → olist_pipeline DAG Trigger
```

### 5. Superset 실행 (로컬)

```bash
cd infra/docker
docker compose -f docker-compose.superset.yml up -d
# localhost:8088 → admin/admin
```

### 6. dbt 수동 실행

```bash
cd transform/olist_pipeline
dbt run
dbt test
```

---

## 🔧 기술 스택

| 구분 | 기술 |
|---|---|
| 스토리지 | Amazon S3 (Data Lake) |
| ETL | AWS Glue (PySpark) |
| 데이터 웨어하우스 | Amazon Redshift |
| 데이터 변환 | dbt Core 1.9.0 |
| 시각화 | Apache Superset (EC2 배포) |
| 오케스트레이션 | Apache Airflow 2.9.0 (Docker) |
| CI/CD | GitHub Actions |
| 인프라 | Terraform, Docker |
| 언어 | Python 3.10 |

---

## 👨‍💻 개발 환경

- **OS:** Windows 10
- **Python:** 3.10.11
- **Docker Desktop:** 4.x
- **AWS:** S3, Glue, Redshift, EC2 (ap-northeast-2 서울 리전)