
# clear the log file
echo > /backups.log
# create backups for immich
docker exec -t immich_postgres pg_dumpall --clean --if-exists --username=postgres | gzip > "/backups/immich.sql.gz"
echo "Backup complete for immich at $(date '+%d-%m-%Y %H:%M:%S')" >> /backups.log
sleep 5
docker exec -t pvt_immich_postgres pg_dumpall --clean --if-exists --username=postgres | gzip > "/backups/pvt-immich.sql.gz"
echo "Backup complete for pvt-immich at $(date '+%d-%m-%Y %H:%M:%S')" >> /backups.log
sleep 5

# create backup for nextcloud
docker exec -u www-data nextcloud bash -c "php occ maintenance:mode --on" > /dev/null
docker exec -t nextcloud-mariadb mysqldump --single-transaction -h localhost -u nextcloud -psecurepassword nextcloud > /backups/nextcloud-mariadb.bak
docker exec -u www-data nextcloud bash -c "php occ maintenance:mode --off" > /dev/null
echo "Backup complete for nextcloud at $(date '+%d-%m-%Y %H:%M:%S')" >> /backups.log
sleep 5

python upload_db.py /backups/immich.sql.gz /backups/pvt-immich.sql.gz /backups/nextcloud-mariadb.bak >> /backups.log

echo "Backup complete for $(date '+%d-%m-%Y')" >> /backups.log