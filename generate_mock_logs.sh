#!/bin/bash
# 🎯 실제 Nginx 볼륨 경로로 정밀 수정
LOG_FILE="$HOME/security-log-pipeline/web/logs/nginx/access.log"

# 임의의 데이터 배열 정의 (다양한 군 분석용 백데이터)
IPS=("211.234.56.78" "14.32.112.5" "192.168.1.50" "10.0.0.12" "124.50.9.112" "54.210.23.4" "185.220.101.5")
STATUS=("200" "200" "200" "301" "404" "403" "500" "503")
METHODS=("GET" "GET" "POST" "GET" "DELETE")
URLS=("/index.html" "/login" "/api/v1/user" "/admin/config" "/products" "/wp-admin/php" "/assets/js/main.js")
AGENTS=("Mozilla/5.0_Windows" "Mozilla/5.0_Macintosh" "PostmanRuntime/7.29.2" "sqlmap/1.6.7" "Nikto/2.1.6")

echo "⏳ 올바른 경로(web/logs/)에 관제용 모의 로그 5,000건 주입 시작..."

# 로그 디렉터리가 혹시 없다면 안전하게 생성
mkdir -p "$(dirname "$LOG_FILE")"

for i in {1..5000}
do
    IP=${IPS[$RANDOM % ${#IPS[@]}]}
    ST=${STATUS[$RANDOM % ${#STATUS[@]}]}
    ME=${METHODS[$RANDOM % ${#METHODS[@]}]}
    URL=${URLS[$RANDOM % ${#URLS[@]}]}
    AG=${AGENTS[$RANDOM % ${#AGENTS[@]}]}
    
    # 금융권 보안 탐지 패턴 유도 (403 Forbidden 및 공격 에이전트 매핑)
    if [ $ST == "403" ]; then
        URL="/admin/config"
        AG="sqlmap/1.6.7"
    fi
    
    TIME=$(date -u +"%d/%b/%Y:%H:%M:%S +0000")
    echo "$IP - - [$TIME] \"$ME $URL HTTP/1.1\" $ST 1542 \"-\" \"$AG\"" >> $LOG_FILE
done

echo "✅ 주입 완료! 이제 올바른 경로에서 Filebeat가 데이터를 긁어 카프카로 쏘기 시작합니다."
