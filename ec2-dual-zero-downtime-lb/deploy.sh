# deploy.sh
REMOTE_USER="ubuntu"
REMOTE_IP_FIRST="3.34.0.32"   # 첫 번째 EC2 인스턴스 IP 주소
REMOTE_IP_SECOND="3.35.66.77" # 두 번째 EC2 인스턴스 IP 주소
DOCKER_COMPOSE_PATH="/home/ubuntu"
NGINX_CONTAINER_NAME="nginx-container"
KATECAM_PEM_KEY_PATH="/home/ubuntu/ssh/key/katecam-key.pem"
LOCAL_INFO_FILE_FIRST="/home/ubuntu/deploy_info_first.txt"
LOCAL_INFO_FILE_SECOND="/home/ubuntu/deploy_info_second.txt"
success_first=0
success_second=0

# 첫 번째 EC2 인스턴스에서 무중단 배포 수행
echo "첫 번째 EC2 인스턴스에서 무중단 배포 시작"
EXIST_KATECAM_BACKEND_FIRST=$(ssh -i $KATECAM_PEM_KEY_PATH $REMOTE_USER@$REMOTE_IP_FIRST 'sudo docker ps | grep katecam-backend-first')

if [ -z "$EXIST_KATECAM_BACKEND_FIRST" ]; then
    AFTER_COLOR_FIRST="first"
    BEFORE_COLOR_FIRST="second"
    AFTER_PORT_FIRST=8080
    BEFORE_PORT_FIRST=8081
else
    AFTER_COLOR_FIRST="second"
    BEFORE_COLOR_FIRST="first"
    AFTER_PORT_FIRST=8081
    BEFORE_PORT_FIRST=8080
fi

# 첫 번째 인스턴스 배포 정보 저장
echo "BEFORE_COLOR=$BEFORE_COLOR_FIRST" > $LOCAL_INFO_FILE_FIRST
echo "AFTER_COLOR=$AFTER_COLOR_FIRST" >> $LOCAL_INFO_FILE_FIRST
echo "BEFORE_PORT=$BEFORE_PORT_FIRST" >> $LOCAL_INFO_FILE_FIRST
echo "AFTER_PORT=$AFTER_PORT_FIRST" >> $LOCAL_INFO_FILE_FIRST

# 첫 번째 인스턴스 배포 및 서버 응답 확인
ssh -i $KATECAM_PEM_KEY_PATH $REMOTE_USER@$REMOTE_IP_FIRST 'bash -s' <<EOF
sudo docker-compose -f /home/ubuntu/docker-compose.katecam-backend-$AFTER_COLOR_FIRST.yml pull
sudo docker-compose -p katecam-backend-$AFTER_COLOR_FIRST -f /home/ubuntu/docker-compose.katecam-backend-$AFTER_COLOR_FIRST.yml up -d

# 서버 응답 확인
success=0
for cnt in {1..10}; do
    STATUS=\$(curl -s http://127.0.0.1:${AFTER_PORT_FIRST}/actuator/health | jq -r '.status')
    if [ "\$STATUS" == "UP" ]; then
        echo "서버가 정상적으로 준비되었습니다. 테이블 생성 확인 완료"
        success=1
        break
    else
        echo "서버가 아직 준비되지 않았습니다. ${cnt}/10 시도중..."
        sleep 10
    fi
done

if [ \$success -eq 0 ]; then
    echo "새로운 서버가 정상적으로 구동되지 않았습니다."
    exit 1
fi
EOF

if [ $? -eq 0 ]; then
    success_first=1
else
    success_first=0
fi

# 두 번째 EC2 인스턴스에서 무중단 배포 수행
echo "두 번째 EC2 인스턴스에서 무중단 배포 시작"
EXIST_KATECAM_BACKEND_SECOND=$(ssh -i $KATECAM_PEM_KEY_PATH $REMOTE_USER@$REMOTE_IP_SECOND 'sudo docker ps | grep katecam-backend-first')

if [ -z "$EXIST_KATECAM_BACKEND_SECOND" ]; then
    AFTER_COLOR_SECOND="first"
    BEFORE_COLOR_SECOND="second"
    AFTER_PORT_SECOND=8080
    BEFORE_PORT_SECOND=8081
else
    AFTER_COLOR_SECOND="second"
    BEFORE_COLOR_SECOND="first"
    AFTER_PORT_SECOND=8081
    BEFORE_PORT_SECOND=8080
fi

# 두 번째 인스턴스 배포 정보 저장
echo "BEFORE_COLOR=$BEFORE_COLOR_SECOND" > $LOCAL_INFO_FILE_SECOND
echo "AFTER_COLOR=$AFTER_COLOR_SECOND" >> $LOCAL_INFO_FILE_SECOND
echo "BEFORE_PORT=$BEFORE_PORT_SECOND" >> $LOCAL_INFO_FILE_SECOND
echo "AFTER_PORT=$AFTER_PORT_SECOND" >> $LOCAL_INFO_FILE_SECOND

# 두 번째 인스턴스 배포 및 서버 응답 확인
ssh -i $KATECAM_PEM_KEY_PATH $REMOTE_USER@$REMOTE_IP_SECOND 'bash -s' <<EOF
sudo docker-compose -f /home/ubuntu/docker-compose.katecam-backend-$AFTER_COLOR_SECOND.yml pull
sudo docker-compose -p katecam-backend-$AFTER_COLOR_SECOND -f /home/ubuntu/docker-compose.katecam-backend-$AFTER_COLOR_SECOND.yml up -d

# 서버 응답 확인
success=0
for cnt in {1..10}; do
    STATUS=\$(curl -s http://127.0.0.1:${AFTER_PORT_SECOND}/actuator/health | jq -r '.status')
    if [ "\$STATUS" == "UP" ]; then
        echo "서버가 정상적으로 준비되었습니다. 테이블 생성 확인 완료"
        success=1
        break
    else
        echo "서버가 아직 준비되지 않았습니다. ${cnt}/10 시도중..."
        sleep 10
    fi
done

if [ \$success -eq 0 ]; then
    echo "새로운 서버가 정상적으로 구동되지 않았습니다"
    exit 1
fi
EOF

if [ $? -eq 0 ]; then
    success_second=1
else
    success_second=0
fi

# 배포 성공 여부에 따른 처리
if [ $success_first -eq 1 ] && [ $success_second -eq 1 ]; then
    # NGINX 설정 파일 업데이트
    echo "server 3.34.0.32:$AFTER_PORT_FIRST;" > /home/ubuntu/nginx/conf.d/service-url-first.inc
    echo "server 3.35.66.77:$AFTER_PORT_SECOND;" > /home/ubuntu/nginx/conf.d/service-url-second.inc

    # NGINX 재로드 및 이전 컨테이너 종료
    echo "모든 서버가 정상적으로 구동되었습니다. NGINX 재로드 및 이전 컨테이너 종료 진행."
    sudo docker exec nginx-container nginx -s reload

    # 첫 번째 인스턴스 이전 컨테이너 종료
    ssh -i $KATECAM_PEM_KEY_PATH $REMOTE_USER@$REMOTE_IP_FIRST "sudo docker-compose -p katecam-backend-$BEFORE_COLOR_FIRST -f $DOCKER_COMPOSE_PATH/docker-compose.katecam-backend-$BEFORE_COLOR_FIRST.yml down"

    # 두 번째 인스턴스 이전 컨테이너 종료
    ssh -i $KATECAM_PEM_KEY_PATH $REMOTE_USER@$REMOTE_IP_SECOND "sudo docker-compose -p katecam-backend-$BEFORE_COLOR_SECOND -f $DOCKER_COMPOSE_PATH/docker-compose.katecam-backend-$BEFORE_COLOR_SECOND.yml down"

    echo "Deploy Completed!!"

else
    # 배포 실패 시 새로 시작된 컨테이너 종료
    echo "배포에 실패하여 새로 시작된 컨테이너를 종료합니다."

    # 첫 번째 인스턴스 새 컨테이너 종료
    ssh -i $KATECAM_PEM_KEY_PATH $REMOTE_USER@$REMOTE_IP_FIRST "sudo docker-compose -p katecam-backend-$AFTER_COLOR_FIRST -f $DOCKER_COMPOSE_PATH/docker-compose.katecam-backend-$AFTER_COLOR_FIRST.yml down"

    # 두 번째 인스턴스 새 컨테이너 종료
    ssh -i $KATECAM_PEM_KEY_PATH $REMOTE_USER@$REMOTE_IP_SECOND "sudo docker-compose -p katecam-backend-$AFTER_COLOR_SECOND -f $DOCKER_COMPOSE_PATH/docker-compose.katecam-backend-$AFTER_COLOR_SECOND.yml down"

    echo "Rollback Completed. NGINX와 기존 컨테이너 상태는 유지됩니다."
    exit 1
fi