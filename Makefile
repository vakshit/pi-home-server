update-immich-version:
	docker compose -f ${HOME}/pi-home-server/services/immich/docker-compose.yml up --force-recreate -d
	docker compose -f ${HOME}/pi-home-server/services/pvt-immich/docker-compose.yml up --force-recreate -d
	docker compose -f ${HOME}/pi-home-server/docker-compose.yml restart nginx
	docker system prune -af

create-albums:
	docker compose -f ${HOME}/pi-home-server/cron/docker-compose.yml up immich-album-creator-akshit-album immich-album-creator-home-album immich-album-creator-akshit-pvt-album

sync_pvt_immich_data:
	rsync -avztu --progress --delete --no-perms --no-owner --no-group /media/akshit/seagate/app-data/pvt-immich/ /media/akshit/onetouch/app-data/pvt-immich/

sync_immich_data:
	rsync -avztu --progress --delete --no-perms --no-owner --no-group /media/akshit/seagate/app-data/immich/ /media/akshit/onetouch/app-data/immich/

vault_backward_sync:
	rsync -avztu --progress --delete --no-perms --no-owner --no-group /media/akshit/seagate/vault/ /media/akshit/onetouch/vault/ --dry-run

vault_forward_sync:
	rsync -avztu --progress --delete /media/akshit/onetouch/vault/ /media/akshit/seagate/vault/ --dry-run

albums_forward_sync:
	rsync -avztu --progress --delete --exclude="*.CR3" /media/akshit/onetouch/Immich/Albums/ /media/akshit/seagate/Immich/Albums/ --dry-run

albums_backward_sync:
	rsync -avztu --progress --delete --exclude="*.CR3" /media/akshit/seagate/Immich/Albums/ /media/akshit/onetouch/Immich/Albums/ --dry-run

cameras_forward_sync:
	rsync -avztu --progress --delete --exclude="*.CR3" /media/akshit/onetouch/Immich/Cameras/ /media/akshit/seagate/Immich/Cameras/ --dry-run

cameras_backward_sync:
	rsync -avztu --progress --delete --exclude="*.CR3" /media/akshit/seagate/Immich/Cameras/ /media/akshit/onetouch/Immich/Cameras/ --dry-run
