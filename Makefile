update-immich-version:
	docker compose -f $HOME/pi-home-server/services/immich/docker-compose.yml up --force-recreate -d
	docker compose -f $HOME/pi-home-server/services/pvt-immich/docker-compose.yml up --force-recreate -d
	docker compose -f $HOME/pi-home-server/docker-compose.yml restart nginx

create-albums:
	docker compose -f $HOME/pi-home-server/cron/docker-compose.yml up immich-album-creator-akshit-album immich-album-creator-home-album immich-album-creator-akshit-pvt-album

