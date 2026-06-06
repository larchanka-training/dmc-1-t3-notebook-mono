# Task

link: https://github.com/larchanka-training/js-notebook/issues/66

```
role: DevOps engineer, BASH expert

task:
  Note that below in a text all docker containers which were created for `docker-compose.yaml` called *project docker containers*.
  Write `stop-services.sh` script which will do opposite things which is done by `start-services.sh` script.
  So, in anyway, despite any parameters it is called, it should *stop* all project docker containers.
  And then additionally:
  - In case when 'cleanup' word specified as CLI parameter it should down all project containers, then keep only `postgres` and `pgadmin4` docker 
  images and remove images for the rest of project docker containers from a system. The idea of keeping these 2 - to avoid downloading hundreds of megabytes when creating these containers again. 
  - In case when 'remove' word specified as CLI parameter it should remove all project docker containers and its images from a system.

constraints:
  It should use case-insensitve comparison for CLI parameter.
  Do not try to kill any processes inside docker container, just stop containers - that is enough.
  By *remove container* I mean *down container, remove it and remove its image*.
  For *removing all project docker containers* use `docker compose down -v --rmi all`
```

test 1 - 20260518,1357
