# 🛡️ 대용량 보안 로그 실시간 수집 및 관제를 위한 SIEM 데이터 파이프라인

본 프로젝트는 가상화 인프라 환경(Docker)을 기반으로 운영 서버의 부하를 최소화하며 대용량 웹 트래픽 로그를 실시간으로 수집하고, 데이터 폭주 상황에서도 유실 없는 안정적인 버퍼링 계층(Kafka) 및 실시간 가공 정제 엔진(Logstash)을 거쳐 분산 저장소(Elasticsearch)와 가시성 도구(Kibana, AKHQ)로 연동되는 End-to-End SIEM(보안 정보 및 이벤트 관리) 데이터 파이프라인 인프라 생태계입니다.

---

## 🏗️ 1. 시스템 아키텍처 (System Architecture)

(```)mermaid
graph LR
    %% 스타일 정의
    classDef producer fill:#e1f5fe,stroke:#039be5,stroke-width:2px;
    classDef agent fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef queue fill:#fff3e0,stroke:#ef6c00,stroke-width:2px;
    classDef etl fill:#fffde7,stroke:#fbc02d,stroke-width:2px;
    classDef storage fill:#ffebee,stroke:#c62828,stroke-width:2px;
    classDef monitor fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px;

    %% 노드 구성
    subgraph Web_Layer [웹 서비스 계층]
        Nginx["🛡️ Nginx Web Server<br/>(Generate access.log)"]
    end

    subgraph Collection_Layer [수집 및 버퍼 계층]
        Filebeat["🚀 Filebeat<br/>(Lightweight Ingestion)"]
        Kafka["🗄️ Apache Kafka Cluster<br/>(Message Buffer & Queue)"]
    end

    subgraph Processing_Layer [가공 및 저장 계층]
        Logstash["⚙️ Logstash<br/>(Grok Parsing & Masking)"]
        Elasticsearch["💾 Elasticsearch<br/>(Distributed Storage)"]
    end

    subgraph Management_Layer [관제 계층]
        AKHQ["📊 AKHQ Web UI<br/>(Topic & Lag Monitoring)"]
        Kibana["👁️ Kibana Dashboard<br/>(Security Visualization)"]
    end

    %% 흐름 및 연결
    Nginx -->|1. 로그 생성| Filebeat
    Filebeat -->|2. 실시간 전송| Kafka
    Kafka -->|3. 로그 이벤터 소비| Logstash
    Logstash -->|4. 정제 및 마스킹 데이터 적재| Elasticsearch
    Kafka -.->|토픽 관제| AKHQ
    Elasticsearch -.->|보안 모니터링| Kibana

    %% 스타일 적용
    class Nginx producer;
    class Filebeat agent;
    class Kafka queue;
    class Logstash etl;
    class Elasticsearch storage;
    class AKHQ monitor;
    class Kibana monitor;

    %% 서브그래프 스타일
    style Web_Layer fill:none,stroke:#cfd8dc,stroke-width:1px;
    style Collection_Layer fill:none,stroke:#cfd8dc,stroke-width:1px;
    style Processing_Layer fill:none,stroke:#cfd8dc,stroke-width:1px;
    style Management_Layer fill:none,stroke:#cfd8dc,stroke-width:1px;
(```)

### 🧩 컴포넌트별 핵심 역할
* **Nginx**: 실제 상용 환경의 웹 서비스를 대변하며 보안 분석의 대상이 되는 원본 로그를 생성합니다.
* **Filebeat**: CPU/Memory 오버헤드가 적은 경량 에이전트로, 오직 `access.log`만을 정밀 타깃팅하여 보안 데이터 노이즈를 방지합니다.
* **Apache Kafka**: 분당 수만 건의 DDoS 공격이나 웹 스캐닝이 발생하는 대규모 장애 상황에서도 로그 유실을 원천 차단하는 완충지대(Buffer) 역할을 수행합니다.
* **Logstash**: 정교한 **Grok 필터**를 통해 통문장 문자열 로그를 필드 단위(`client_ip`, `status_code`, `request` 등)로 파싱하고, 금융권 보안 가이드라인을 준수하여 내부 자산 및 개인정보 보호를 위한 **IP 주소 뒷자리 마스킹 처리(`172.18.0.xxx`)**를 수행하는 ETL 엔진입니다.
* **Elasticsearch**: 대용량 가공 로그를 실시간으로 인덱싱하는 분산형 빅데이터 저장소입니다.
* **Kibana & AKHQ**: 파이프라인의 실시간 데이터 인젝션 상태를 시각적으로 추적하고 침입 흔적을 한눈에 식별할 수 있도록 지원하는 웹 관제 솔루션입니다.

---

## 🛠️ 2. 인프라 검증 및 엔지니어링 아카이빙
본 프로젝트는 가상화 커널 호환성 문제를 극복하고, 실제 운영 한계점을 정량적으로 도출하기 위해 하드한 대규모 부하 테스트(BMT)를 거쳐 인프라의 신뢰성을 직접 검증했습니다.

* 🔍 [인프라 호환성 및 권한 장애 트러블슈팅 문서 바로가기](./docs/TROUBLE_SHOOTING.md)
* 📈 [대규모 부하 테스트(TPS) 및 정량적 성능 검증 문서 바로가기](./docs/BENCHMARK_TEST.md)

### 📊 벤치마크 요약 성능 지표 (Key Results)
* **최대 로그 수집 처리량**: **12,214.22 TPS** 달성 (Apache Bench 동시성 100 기준)
* **종단 간 데이터 유실률**: **0.00% (Zero Leakage)** 입증 (10,000건 인젝션 후 Elasticsearch 실물 인덱스 전수 검증 완료)
* **평균 트래픽 응답 속도**: **8.187 ms**로 매우 촘촘하고 안정적인 네트워킹 상태 확보

---

## 🚀 3. 시작하기 (Quick Start)

현실 세계(호스트 리눅스)와 컨테이너 환경을 격리 및 동기화하기 위해 디렉토리를 바인드 마운트하여 구동합니다.

(```)bash
# 1. 원본 로그 저장 디렉토리 선제 생성
mkdir -p web/logs/nginx

# 2. 인프라 전체 일괄 기동 (백그라운드)
docker compose up -d

# 3. 테스트용 의도적 부하 트래픽 주입 (15회 자동 호출)
for i in {1..15}; do curl -s http://localhost > /dev/null; done
(```)

* **AKHQ 토픽 웹 관제**: 브라우저에서 `http://localhost:8080` 접속
* **Kibana 실시간 보안 관제 (Discover)**: 브라우저에서 `http://localhost:5601` 접속 후 `nginx-security-logs-*` 데이터 뷰 등록
