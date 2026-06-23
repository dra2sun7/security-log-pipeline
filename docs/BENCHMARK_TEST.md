# 📈 인프라 성능 검증 및 대규모 부하 테스트 (BMT) 일지

본 문서는 구축된 SIEM 데이터 파이프라인의 신뢰성과 초당 트래픽 처리량(TPS), 그리고 자원 최적화 효율을 정량적으로 검증하기 위한 벤치마크 테스트 기록입니다.

---

## 🏎️ [시나리오 1] Apache Bench 기반 대규모 트래픽 부하 테스트
- **테스트 일시**: 2026-06-23
- **테스트 목적**: 대량의 웹 스캐닝 및 DDoS 공격 상황을 가정한 인프라 인젝션 및 초당 처리량(TPS) 측정
- **테스트 조건**: 전처리 데이터 적재 정밀도 100% 검증을 위해 기존 Elasticsearch 인덱스를 완전 초기화(DELETE) 후 클린 상태에서 진행.

### 📍 1. Apache Bench 원본 리포트 (Raw Data)
```text
This is ApacheBench, Version 2.3 <$Revision: 1903618 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking localhost (be patient)
Completed 1000 requests
Completed 2000 requests
Completed 3000 requests
Completed 4000 requests
Completed 5000 requests
Completed 6000 requests
Completed 7000 requests
Completed 8000 requests
Completed 9000 requests
Completed 10000 requests
Finished 10000 requests


Server Software:        nginx/1.31.2
Server Hostname:        localhost
Server Port:            80

Document Path:          /
Document Length:        896 bytes

Concurrency Level:      100
Time taken for tests:   0.819 seconds
Complete requests:      10000
Failed requests:        0
Total transferred:      11290000 bytes
HTML transferred:       8960000 bytes
Requests per second:    12214.22 [#/sec] (mean)
Time per request:       8.187 [ms] (mean)
Time per request:       0.082 [ms] (mean, across all concurrent requests)
Transfer rate:          13466.65 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   0.9      1       4
Processing:     0    7   6.7      6      86
Waiting:        0    7   6.5      5      82
Total:          0    8   6.6      7      88

Percentage of the requests served within a certain time (ms)
  50%      7
  66%      8
  75%      9
  80%     10
  90%     12
  95%     14
  98%     21
  99%     42
 100%     88 (longest request)
```

### 🎯 2. 핵심 성능 지표 분석 (Key Metrics)
1. **Concurrency Level (동시 접속 수)**: 100
2. **Complete requests (성공한 총 요청 수)**: 10,000
3. **Requests per second (초당 로그 처리량)**: 12,214.22 TPS 🔥
4. **Time per request (평균 응답 속도)**: 8.187 ms
5. **Elasticsearch 인덱스 검증**: 기존 인덱스를 완전 초기화(DELETE) 후 테스트를 진행한 결과, `docs.count`가 정확히 10,000건으로 수렴함을 확인하여 파이프라인 내 **데이터 유실률 0.00%**를 정량적으로 증명함.
   - *특이사항 (인프라 상태 분석)*: 인덱스 상태가 `yellow`로 식별됨. 이는 Single Node 환경 특성상 Primary Shard(원본)는 정상 배치되었으나 Replica Shard(복사본)를 분산 배치할 추가 노드가 존재하지 않아 발생한 현상으로, 읽기/쓰기 무결성에는 지표상 이상이 없음을 아키텍처적으로 검증함.
---
