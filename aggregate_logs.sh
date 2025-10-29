#!/usr/bin/env bash
mkdir -p logs
docker-compose logs -f --no-color | tee -a logs/all_containers.log
