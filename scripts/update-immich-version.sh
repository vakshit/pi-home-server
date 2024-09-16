#!/bin/bash

docker compose -f $HOME/pi-home-server/services/immich/docker-compose.yml up --force-recreate -d
docker compose -f $HOME/pi-home-server/services/pvt-immich/docker-compose.yml up --force-recreate -d
docker compose -f $HOME/pi-home-server/docker-compose.yml restart nginx
