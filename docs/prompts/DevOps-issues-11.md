
# Creating Dockerfile

## Prepare dockerfiles

As discovered I incorrectly cloned `mono-repo` that is why `api` and `ui` folders were empty.
Thus, following this wrong way I tried to create "zero-point-projects" for both `api` and `ui`.
Now I cloned mono-repo correctly and now `api` and `ui` folders are not empty.
So, need to re-do this task.

AI prompt:
```
role: Software Architect, DevOps engineer, Python and React developer
task:
  1. check `docker-compose.yaml` file, create missing docker files
  2. ensure `bash` installed for api and ui docker images
  3. ensure `api` and `ui` projects use `.env` file to read parameters from
  4. ensure `api` and `ui` projects use bindMound 
  5. ensure to create default configuration for `alembic` in `api` project
  6. ensure to check `api` project to there will not be `CORS policy` error when making API calls
  7. change ports for `proxy` project from 80 and 443 to 8080 and 8443
constrains:
  - use python 3.12
  - do not touch `.env.example` file - that is only abstract example.
  - if only possible keep `start-services.sh` script as-is
  - minimize changes to `docker-compose.yaml` file, if it use `sh` - keep it
  - do not change `fastapi` CLI with `unicorn`
  - check if `fastapi` CLI is available and add required dependencies if required
  - ensure `npm` also install optional dependencies 
```



## When success

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

Asked AI to add dependency and prepare minimal/default config `alembic`.

Now it starts... but still some problems - there is API call failure.


## API call failure: {url} has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present on the requested resource.

```
'http://localhost:3000' has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

Asked AI to help - it modified 


## Error response from daemon: error while creating mount source path '/run/desktop/mnt/host/w/larchanka/dmc-1-t3-notebook-mono/api': mkdir /run/desktop/mnt/host/w: file exists

It tells that when moundBind is used then running project on drive W: may make it fail.
It recommends to move it drive C:, restart Docker Desktop, run `wsl --shutdown`.
Then rebuild compose - `docker compose up -d --build`

Ok. Moved to `C:\sbx\edu\dmc-1-t3-notebook-mono`... seems now it works.


## `api` container fail to start.

There was error in log - kind of "missing fastapi command, please use fastapi[standard] in requirements.txt".
Fixed.

```
To use the fastapi command, please install "fastapi[standard]":
api-1  | Traceback (most recent call last):
api-1  |   File "/usr/local/bin/fastapi", line 8, in <module>
api-1  |     sys.exit(main())
api-1  |              ^^^^^^
api-1  |   File "/usr/local/lib/python3.12/site-packages/fastapi/cli.py", line 12, in main
api-1  |     raise RuntimeError(message)  # noqa: B904
api-1  |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^
api-1  | RuntimeError: To use the fastapi command, please install "fastapi[standard]":
```


## Error: frontend container fail to start
```
Error: Cannot find module @rollup/rollup-linux-x64-musl. npm has a bug related to optional dependencies (https://github.com/npm/cli/issues/4828). Please try `npm i` again after removing both package-lock.json and node_modules directory.
frontend-1  |     at requireWithFriendlyError (/home/app/node_modules/rollup/dist/native.js:115:9)
```

AI tells that failure was because of missing optional updated during npm install.
Suggested to fix `dockerfile` and `docker-compose.yaml`:
```
RUN npm ci --include=optional
sh -c "cd /home/app && npm ci --include=optional && npm run dev"
```



# How-To

## how to delete all which was created from docker-compose.yaml ?

- standard delete: `docker compose down`
- delete with data volumed: `docker compose down -v`
- delete with local image: `docker compose down --rmi local`
- maximum cleanup: `docker compose down -v --rmi all`

