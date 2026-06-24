# 🛡️ 금융권 규격 고가용성(HA) 데이터 파이프라인 이중화 설계 제안서

본 문서는 단일 장애점(SPOF, Single Point of Failure)을 원천 제거하고, 금융권의 까다로운 전자금융감독규정(상시 가용성 및 재해복구 체계)을 충족하기 위한 엔터프라이즈급 이중화 및 분산 클러스터링 확장 가이드라인입니다.

---

## 🏗️ 1. 목표 아키텍처: Active-Active 고가용성 토폴로지

기존의 단일 컨테이너 레이어를 전 구간 분산 노드로 확장하여, 특정 인프라 장비가 물리적으로 파괴되거나 다운되어도 데이터 유실률 0%와 서비스 무중단을 보장합니다.

```mermaid
graph TB
    %% 스타일 정의
    classDef lb fill:#eceff1,stroke:#607d8b,stroke-width:2px;
    classDef web fill:#e1f5fe,stroke:#039be5,stroke-width:2px;
    classDef queue fill:#fff3e0,stroke:#ef6c00,stroke-width:2px;
    classDef etl fill:#fffde7,stroke:#fbc02d,stroke-width:2px;
    classDef storage fill:#ffebee,stroke:#c62828,stroke-width:2px;

    %% 외부 유입
    Client["🌐 외부 대규모 웹 트래픽"] --> L4["⚖️ L4 Load Balancer<br/>(Round-Robin / Least-Conn)"]

    %% 웹 계층 이중화
    subgraph Web_Cluster [Web Server Layer (Active-Active)]
        Nginx1["🛡️ Nginx Node 1"]
        Nginx2["🛡️ Nginx Node 2"]
    end
    L4 --> Nginx1
    L4 --> Nginx2

    %% 수집 및 버퍼 계층 이중화
    subgraph Ingestion_Buffer_Layer [Distributed Queue Layer]
        Filebeat1["🚀 Filebeat 1"] ---> Kafka1
        Filebeat2["🚀 Filebeat 2"] ---> Kafka2
        
        subgraph Kafka_Cluster [Apache Kafka Cluster (3-Node)]
            Kafka1["🗄️ Broker 1"] <--> Kafka2["🗄️ Broker 2"]
            Kafka2 <--> Kafka3["🗄️ Broker 3"]
        end
    end
    Nginx1 --> Filebeat1
    Nginx2 --> Filebeat2

    %% 가공 계층 이중화
    subgraph Processing_Layer [Logstash Consumer Group]
        Logstash1["⚙️ Logstash Node 1"]
        Logstash2["⚙️ Logstash Node 2"]
    end
    Kafka_Cluster ---> Logstash1
    Kafka_Cluster ---> Logstash2

    %% 저장 계층 이중화
    subgraph Storage_Layer [Elasticsearch Data Node Cluster]
        Logstash1 --> ES_Cluster
        Logstash2 --> ES_Cluster
        
        subgraph ES_Cluster [Elasticsearch Cluster (3-Node)]
            ES1["💾 Master/Data Node 1<br/>(Primary Shard A)"] <--> ES2["💾 Data Node 2<br/>(Replica Shard A / Primary Shard B)"]
            ES2 <--> ES3["💾 Data Node 3<br/>(Replica Shard B)"]
        end
    end

    %% 스타일 적용
    class L4 lb;
    class Nginx1,Nginx2 web;
    class Kafka1,Kafka2,Kafka3 queue;
    class Logstash1,Logstash2 etl;
    class ES1,ES2,ES3 storage;
```

---

## 🎯 2. 컴포넌트별 고가용성(HA) 구성 전략

### 1) Nginx 웹 레이어: Active-Active 이중화
* **설계**: 최전방에 물리 **L4 로드밸런서**를 배치하여 트래픽을 상시 분산 처리.
* **장애 시나리오**: `Node 1`이 다운되더라도 L4 헬스체크 메커니즘에 의해 즉시 `Node 2`로 100% 트래픽이 전송되어 무중단 서비스 제공.

### 2) Apache Kafka: 3-Broker 멀티 노드 클러스터 구축
* **설계**: 최소 3대의 브로커로 분산 클러스터를 구성하고 토픽의 **`Replication Factor: 3`**, **`min.insync.replicas: 2`** 옵션을 강제 적용.
* **금융권 신뢰성 무결성**: 수집기(Filebeat) 전송 시 `acks=all` 설정을 적용하여, 최소 2대 이상의 브로커에 로그가 복제 완료되었음을 확인해야 웹 서버가 안심하고 다음 연산을 수행하도록 보장 (금융권 수준의 데이터 무손실 보장).

### 3) Logstash: Consumer Group 로드 밸런싱
* **설계**: 동일한 `group.id`를 공유하는 다중 Logstash 인스턴스를 수평 확장(Scale-out).
* **장애 시나리오**: 특정 Logstash 컨테이너가 가동 중단될 경우, Kafka의 **리밸런싱(Rebalancing)** 메커니즘에 의해 대기 중인 다른 Logstash 노드가 즉시 파티션 소유권을 이관받아 가공 공백 최소화.

### 4) Elasticsearch: Multi-Node 분산 클러스터 (Status: GREEN 🟢)
* **설계**: 3개 이상의 노드로 클러스터를 바인딩하고 `number_of_replicas: 1` 설정 적용.
* **기대 효과**: 원본방(Primary Shard)과 복사본방(Replica Shard)이 절대 동일 노드에 배치되지 않도록 격리하여, 싱글 노드 당시 발생했던 **`Yellow` 경고등을 `Green` 상태로 승격**시키고 하드웨어 고장에 완벽 대응.

---

## 📈 3. 향후 2차 로드맵 및 인프라 구현 계획
1. `docker-compose-ha.yml` 프로덕션용 인프라 매니페스트 파일 분리 작성.
2. 각 분산 컴포넌트 레이어 간 사설 네트워크 브릿지 대역 고도화 및 데이터 동기화 지연(Replication Lag) 격리 테스트 수행.
