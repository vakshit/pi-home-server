update-immich-version:
	docker compose pull
	docker compose -f ${HOME}/pi-home-server/services/immich/docker-compose.yml up --force-recreate -d
	sleep 20
	docker system prune -af
	sleep 10
	docker compose -f ${HOME}/pi-home-server/cron/docker-compose.yml create immich-album-creator-akshit-album immich-album-creator-home-album immich-album-creator-akshit-pvt-album immich-album-creator-jiya-album
	sleep 10
	docker compose -f ${HOME}/pi-home-server/docker-compose.yml restart nginx

create-albums:
	docker compose -f ${HOME}/pi-home-server/cron/docker-compose.yml up immich-album-creator-akshit-album immich-album-creator-home-album immich-album-creator-akshit-pvt-album immich-album-creator-jiya-album

sync_pvt_immich_data:
	rsync -avztu --progress --delete --no-perms --no-owner --no-group /media/akshit/seagate/app-data/pvt-immich/ /media/akshit/onetouch/app-data/pvt-immich/

sync_immich_data:
	rsync -avztu --progress --delete --no-perms --no-owner --no-group /media/akshit/seagate/app-data/immich/ /media/akshit/onetouch/app-data/immich/

vault_backward_sync:
	rsync -avztu --progress \
	--exclude="*.xmp" --exclude="*.mp3" --exclude="*m4a" --exclude="*.txt" --exclude="*.CR3" --exclude="Aditi Google" --exclude="excluded" \
	--no-perms --no-owner --no-group \
	--delete \
	/media/akshit/seagate/vault/ /media/akshit/onetouch/vault/ \
	--dry-run

vault_forward_sync:
	rsync -avztu --progress \
	--exclude="*.xmp" --exclude="*.mp3" --exclude="*m4a" --exclude="*.txt" --exclude="*.CR3" --exclude="Aditi Google" --exclude="excluded" \
	--no-perms --no-owner --no-group \
	--delete \
	/media/akshit/onetouch/vault/ /media/akshit/seagate/vault/ \
	--dry-run

albums_forward_sync:
	rsync -avztu --progress --no-perms --no-owner --no-group --delete --exclude="*.xmp" --exclude="*.CR3" /media/akshit/onetouch/Immich/Albums/ /media/akshit/seagate/Immich/Albums/ --dry-run

albums_backward_sync:
	rsync -avztu --progress --no-perms --no-owner --no-group --delete --exclude="*.xmp" --exclude="*.CR3" /media/akshit/seagate/Immich/Albums/ /media/akshit/onetouch/Immich/Albums/ --dry-run

cameras_forward_sync:
	rsync -avztu --progress --no-perms --no-owner --no-group --delete --exclude="*.xmp" --exclude="*.CR3" /media/akshit/onetouch/Immich/Cameras/ /media/akshit/seagate/Immich/Cameras/ --dry-run

cameras_backward_sync:
	rsync -avztu --progress --no-perms --no-owner --no-group --delete --exclude="*.xmp" --exclude="*.CR3" /media/akshit/seagate/Immich/Cameras/ /media/akshit/onetouch/Immich/Cameras/ --dry-run

akshit_albums_forward_sync:
	rsync -avztu --progress --no-perms --no-owner --no-group --delete --exclude="*.xmp" --exclude="*.CR3" /media/akshit/onetouch/Immich/Albums_Akshit/ /media/akshit/seagate/Immich/Albums_Akshit/ --dry-run

akshit_albums_backward_sync:
	rsync -avztu --progress --no-perms --no-owner --no-group --delete --exclude="*.xmp" --exclude="*.CR3" /media/akshit/seagate/Immich/Albums_Akshit/ /media/akshit/onetouch/Immich/Albums_Akshit/ --dry-run
