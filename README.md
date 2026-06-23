# 🛡️ 대용량 보안 로그 실시간 수집 및 관제를 위한 SIEM 데이터 파이프라인

본 프로젝트는 가상화 인프라 환경(Docker)을 기반으로 운영 서버의 부하를 최소화하며 대용량 웹 트래픽 로그를 실시간으로 수집하고, 데이터 폭주 상황에서도 유실 없는 안정적인 버퍼링 계층(Kafka)을 구축하여 모니터링하는 SIEM(보안 정보 및 이벤트 관리) 파이프라인의 기초 인프라 생태계입니다.

---

## 🏗️ 1. 시스템 아키텍처 (System Architecture)

```mermaid
graph LR
    %% 스타일 정의
    classDef producer fill:#e1f5fe,stroke:#039be5,stroke-width:2px;
    classDef agent fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef queue fill:#fff3e0,stroke:#ef6c00,stroke-width:2px;
    classDef monitor fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px;

    %% 노드 구성
    subgraph Web_Layer [웹 서비스 계층]
        Nginx["🛡️ Nginx Web Server<br/>(Generate access.log)"]
    end

    subgraph Collection_Layer [수집 및 버퍼 계층]
        Filebeat["🚀 Filebeat<br/>(Lightweight Ingestion)"]
        Kafka["🗄️ Apache Kafka Cluster<br/>(Message Buffer & Queue)"]
    end

    subgraph Management_Layer [관제 계층]
        AKHQ["📊 AKHQ Web UI<br/>(Topic & Lag Monitoring)"]
    end

    %% 흐름 및 연결 (특수문자 에러 수정)
    Nginx -->|1. 로그 생성| Filebeat
    Filebeat -->|2. 실시간 전송 Port 9092| Kafka
    Kafka -.->|3. 토픽 및 컨슈머 모니터링| AKHQ

    %% 스타일 적용
    class Nginx producer;
    class Filebeat agent;
    class Kafka queue;
    class AKHQ monitor;

    %% 서브그래프 스타일
    style Web_Layer fill:none,stroke:#cfd8dc,stroke-width:1px;
    style Collection_Layer fill:none,stroke:#cfd8dc,stroke-width:1px;
    style Management_Layer fill:none,stroke:#cfd8dc,stroke-width:1px;
```

* **Nginx**: 실제 상용 환경의 웹 서비스를 대변하며 보안 분석의 대상이 되는 원본 로그를 생성합니다.
* **Filebeat**: CPU/Memory 오버헤드가 적은 경량 에이전트로, 오직 `access.log`만을 정밀 타깃팅하여 노이즈를 차단합니다.
* **Apache Kafka**: 분당 수만 건의 DDoS 공격이나 웹 스캐닝이 발생하는 장애 상황에서도 로그 유실을 원천 차단하는 완충지대(Buffer) 역할을 수행합니다.
* **AKHQ**: 가상망 내부의 토픽 데이터 및 컨슈머 지연(Lag) 상태를 실시간 시각화 관제합니다.

---

## 🛠️ 2. 인프라 검증 및 엔지니어링 아카이빙
본 프로젝트는 가상화 커널 호환성 문제를 해결하고 대규모 부하 테스트를 통해 데이터 정밀도를 정량적으로 검증했습니다.

* 🔍 [인프라 호환성 및 권한 장애 트러블슈팅 문서 바로가기](./docs/TROUBLE_SHOOTING.md)
* 📈 [대규모 부하 테스트(TPS) 및 성능 검증 문서 바로가기](./docs/BENCHMARK_TEST.md)

---

## 🚀 3. 시작하기 (Quick Start)

현실 세계(호스트 리눅스)와 컨테이너 환경을 격리 및 동기화하기 위해 디렉토리를 바인드 마운트하여 구동합니다.

```bash
# 1. 원본 로그 저장 디렉토리 선제 생성
mkdir -p web/logs/nginx

# 2. 인프라 일괄 기동
docker compose up -d

# 3. 테스트용 의도적 트래픽 주입 (15회 자동 호출)
for i in {1..15}; do curl -s http://localhost > /dev/null; done
```

* **Kafka 실시간 데이터 구독 확인:**
```bash
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic nginx-access-logs --from-beginning
```
* **AKHQ 토픽 웹 관제:** 브라우저에서 `http://localhost:8080` 접속
