#1
EXIST_KATECAM_BACKEND=$(sudo docker ps | grep katecam-backend-first)

if [ -z "$EXIST_KATECAM_BACKEND" ]; then
	echo "katecam-backend-first 컨테이너 실행"
	sudo docker-compose -p katecam-backend-first -f /home/ubuntu/docker-compose.katecam-backend-first.yml up -d
	BEFORE_COLOR="second"
	AFTER_COLOR="first"
	BEFORE_PORT=8081
	AFTER_PORT=8080

else
	echo "katecam-backend-second 컨테이너 실행"
	sudo docker-compose -p katecam-backend-second -f /home/ubuntu/docker-compose.katecam-backend-second.yml up -d
	BEFORE_COLOR="first"
	AFTER_COLOR="second"
	BEFORE_PORT=8080
	AFTER_PORT=8081
fi

echo "${AFTER_COLOR} server up(port: ${AFTER_PORT})"

#2
success=0
for cnt in $(seq 1 10)
do
	echo "서버 응답 확인중(${cnt}/10)";
	STATUS=$(curl -s http://127.0.0.1:${AFTER_PORT}/actuator/health | jq -r '.components.customDatabase.status')
	if [ "$STATUS" == "UP" ]
	then
		echo "서버가 정상적으로 준비되었습니다. 테이블 생성 확인 완료"
		success=1
		break
	else
		echo "서버가 아직 준비되지 않았습니다. ${cnt}/10 시도중..."
	       	sleep 10
	fi
done

if [ $success -eq 0 ]
then
	echo "새로운 서버가 정상적으로 구동되지 않았습니다. 기존 서버를 유지합니다."
	sudo docker-compose -p katecam-backend-${AFTER_COLOR} -f /home/ubuntu/docker-compose.katecam-backend-${AFTER_COLOR}.yml down
	exit 1
fi

#3
sudo sed -i "s/${BEFORE_PORT}/${AFTER_PORT}/" /home/ubuntu/nginx/conf.d/service-url.inc
sudo docker exec nginx-container nginx -s reload
echo "Deploy Completed!!"

#4
echo "katecam-backend-${BEFORE_COLOR} server down(port: ${BEFORE_PORT})"
sudo docker-compose -p katecam-backend-${BEFORE_COLOR} -f /home/ubuntu/docker-compose.katecam-backend-${BEFORE_COLOR}.yml down



