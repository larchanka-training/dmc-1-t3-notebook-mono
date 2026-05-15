
# Creating Dockerfile

## Prepare zero-project

Initial AI prompt:
```
role: Software Architect, Python expert and React developer
task:
  1. read docs/tech_stack.md

  2. prepare simple backend project inside `api` folder. App parameters should be specified in `api/.env` file. Expose minimal API from backend project, ex: it should handle `/v1/api/version` request with responding app version and "hello world" message. Please note: it should use Python 3.12

  3. prepare simple frontend project in 'ui' folder. It should call `/v1/api/version` API on backend and show version and message on a screen. Address where backend is running it should take from parameter in `ui/.env. file.

  4. Check `docker-compose.yaml` file to see what ports should be used for `api` and for `ui` apps. create appropriate  dockerfile if any is missing

  5. both `api` and `ui` projects should map project folder on host PC into a docker container, so user can change code and it should affect running container to see the result 

  6. ensure `bash` installed into docker containers to ensure setup is compatible with `start-services.sh` script

  7. Modify `proxy/nginx.conf` config to change ports from 80 and 443 to 8080 and 8443.
```

**Hint by VsCode**: An environment file is configured but terminal environment injection is disabled. Enable "python.terminal.useEnvFile" to use environment variables from .env files in terminals.

It should prepare 2 simple projects - `api` and `ui` and update basic 2 dockerfiles which I prepared before.

Then need to start `docker compose up -d --build --force-recreate` to rebuild all services.

Then you can run `./start-services.sh` in a root of mono-repo.

If all was ok, then there will be following services available:
- http://localhost:5050 - pgAgmin
- http://localhost:8000 - backend
- http://localhost:3000 - frontend
- postgreSQL on port 5432 



### If need to drop/re-create all containers

```
docker compose down --volumes --remove-orphans
./start-services.sh
```



## Errors & Issues

### Port 5432 was busy

Strange error:
```
Error response from daemon: ports are not available: exposing port TCP 0.0.0.0:5432 -> 127.0.0.1:0: listen tcp 0.0.0.0:5432: bind: An attempt was made to access a socket in a way forbidden by its access permissions.
```

Check...
```
netstat -ano | findstr :5432
Get-NetTCPConnection -LocalPort 5432 | Format-Table -Property LocalAddress, LocalPort, OwningProcess, State
```

No any records for port 5432!

Tested with my TcpServer tool - got error:
```
Server activation failed: Socket bind failed: Socket permission denied.
```
so, port# 5432 is really allocated by some app. But I cannot find - by which one?!

According to explanation it could be due to system dynamic ports reservation.

Fixing dynamic ports selection for a system:
```
netsh int ipv4 set dynamicport tcp start=49152 num=4096
netsh int ipv4 set dynamicport udp start=49152 num=4096

# stop vnet services
net stop hns
net stop wna

# restart net address translator
net stop winnat
net start winnat

# run vnet services back
net start wna
net start hns
```

### Problem: docker fail to update from 4.71.0 to 4.73.1
```
fork/exec C:\Users\Dmitr\AppData\Local\Temp\DockerDesktopUpdates\Docker Desktop Installer (226574).exe: The requested operation requires elevation.
```

Goto to `C:\Users\%UserName%\AppData\Local\Temp\DockerDesktopUpdates\`
Find there last update package (ex: Docker Desktop Updater-225177 (226574).exe)
Run it as Admin.


### Docker error - OCI runtime exec failed
```
Error response from daemon: OCI runtime exec failed: exec failed: unable to start container process: exec: "bash": executable file not found in $PATH
```

Existing `start-services.sh` script use bash but bash is not part of slim/alpine docker images. 
So, need to replace with `sh` or install `bash` explicitly.

It tells - bash is not installed by default for slim/alpine images.
Added `RUN apk update && apk add bash openssl` to ui/dockerfile
Modified `RUN apt-get update && apt-get install -y --no-install-recommends bash && rm -rf /var/lib/apt/lists/*` 
in `api/dockerfile`

Then need to explicitly rebuild both containers:
```
docker-compose build api frontend
```


### Error: ports are not available: exposing port TCP 0.0.0.0:80 
```
Error response from daemon: ports are not available: exposing port TCP 0.0.0.0:80 -> 127.0.0.1:0: listen tcp 0.0.0.0:80: bind: An attempt was made to access a socket in a way forbidden by its access permissions.
```

On Windows need to stop IIS - (run as admin) `iisreset /stop`
If not helped then also - `net stop http`
And then you may also need to stop following services:
```
net stop PeerDist 
net stop BranchCache

net stop W3SVC

net stop MsDepSvc

net stop "Work Folders" 
net stop "Sync Share"
```

Then validate if port 80 is free now - `netstat -an | findstr :80`

Then run `docker compose up -d --build --force-recreate` to force rebuild all.

Then can run `./start-services.sh` in a root of mono-repo.


## API container start and immediately stopped

As discovered there is ref to `alembic upgrade head` in `docker-compose.yaml` file.
API container needs a alembic lib with some basic config to be able to start with such compose configuration.

Asked AI to add dependency and prepare minimal/default config alembic.

Now it starts... but still some problems - there is API call failure.


## API call failure: {url} has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present on the requested resource.

```
'http://localhost:3000' has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

Asked AI to help - it modified 



# How-To

## how to delete all which was created from docker-compose.yaml ?

standard delete: `docker compose down`
delete with data volumed: `docker compose down -v`
delete with local image: `docker compose down --rmi local`
maximum cleanup: `docker compose down -v --rmi all`

