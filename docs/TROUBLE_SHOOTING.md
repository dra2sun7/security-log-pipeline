# 🔍 인프라 호환성 버그 및 데이터 병목 트러블슈팅 기록

본 문서는 파이프라인 인프라 구축 중 발생한 예외 상황(Exception)과 아키텍처적 결함을 실무 기술 역량으로 고도화한 엔지니어링 일지입니다.

---

## 🔥 1. WSL2 커널과 자바 런타임 간의 cgroup v2 호환성 장애
* **현상**: 인프라 구동 시 부모 코디네이터인 Zookeeper 컨테이너가 시작 직후 원인 불명의 `java.lang.NullPointerException`을 뿜으며 비정상 종료(Exited)됨. 이로 인해 자식 브로커인 Kafka가 `UnknownHostException`을 유발하며 도미노 붕괴 발생.
* **원인 분석**: 최신 WSL2 우분투 환경은 시스템 자원 관리를 위해 `cgroup v2` 메커니즘을 사용하나, 기존에 채택했던 구버전 Zookeeper 이미지(`cp-zookeeper:7.3.0`) 내부의 Java 11 런타임이 이를 파싱하지 못해 발생한 호환성 결함 확인.
* **해결 조치**: 해당 JVM 호환성 패치가 완료된 Confluent 공식 최신 메이저 에디션인 **`7.5.0` 버전으로 스택을 핀포인트 업그레이드**하여 NullPointer 예외를 원천 제거하고 클러스터 체결 성공.

---

## 🔥 2. Docker 가상 볼륨(Named Volume) 격리로 인한 수집 차단 현상
* **현상**: Nginx 웹 서버에는 실시간 웹 로그가 누적되는 것을 확인했으나, 수집 에인전트인 Filebeat 로그 메트릭스에서 `"open_files":0, "running":0` 상태가 지속되며 대기열 전송 병목 발생.
* **원인 분석**: 
  1. `nginx_logs:/var/log/nginx` 형태의 Named Volume 선언 시, 도커 엔진이 관리하는 깊은 격리 구역에 파일이 물리적으로 숨겨짐.
  2. 일반 사용자(`kakaouser`) 권한 세션과 관리자(`root`) 권한 세션 간의 마운트 링크가 WSL2 환경 내부에서 비정상적으로 동기화가 끊기는 고질적 링커 버그 추적.
* **해결 조치**: 
  * 이름뿐인 가상 공간 공유 방식을 폐기하고, 호스트 리눅스의 실제 디렉토리 경로인 `/home/kakaouser/security-log-pipeline/web/logs/nginx`를 직접 공유하는 **호스트 바인드 마운트(Bind Mount)** 구조로 아키텍처 변경.
  * 불필요한 에러 로그 수집으로 인한 데이터 오염(Noise)을 방지하기 위해 `filebeat.yml` 경로를 오직 `access.log` 단건 파일만 추적하도록 엄격하게 정렬하여 `"open_files":1, "running":1` 수집 정상화 달성.
