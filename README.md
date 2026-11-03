# 개발자용 '작업실' 꾸미기 — 개발 워크스테이션 구축 (WSL2 + Docker + Git)

> **한 줄 소개:** Windows에서 WSL2(Ubuntu)·Docker·Git/GitHub를 직접 세팅해, "내 PC에서만 되는" 상태를 벗어나 **누구나 같은 절차로 실행·공유할 수 있는** 개발 환경을 만든 기록이다.

## 빠른 실행 (재현)

```bash
# 1) 레포 복제
git clone https://github.com/QWERQWER-qwer/codyssey-dev-workstation.git
cd codyssey-dev-workstation

# 2) 커스텀 이미지 빌드 후 실행
docker build -t my-web:1.0 .
docker run -d -p 8080:80 --name my-web-8080 my-web:1.0
# 브라우저에서 http://localhost:8080 접속

# (대안) Docker Compose 한 줄 실행 → http://localhost:8083
docker compose up -d
```

---

## 1. 왜 이 작업을 했나 (문제 제기)

개발을 시작할 때 가장 먼저 부딪히는 건 코드가 아니라 **환경**이었다. 같은 코드도 설치 방법이 사람마다 달라 "내 PC에선 되는데" 하는 재현 실패가 잦다. 이 과제는 터미널·Docker·Git이라는 세 도구를 직접 손으로 세팅해, 그 상태를 벗어나 **누구나 같은 절차로 실행·공유·디버깅할 수 있는 개발 작업실**을 만드는 것을 목표로 한다.

## 2. 실행 환경

| 항목 | 값 |
|---|---|
| OS | Windows 11 (버전 10.0.26200.9711) + WSL2 |
| 배포판 | Ubuntu 26.04.1 LTS |
| 커널 | 6.18.54.1-microsoft-standard-WSL2 |
| Shell / Terminal | bash / Windows Terminal |
| Docker | 29.9.2 (build a82e528) — Docker Desktop 4.97.0, WSL2 backend |
| Docker Compose | v5.6.1 |
| Git | 2.53.0 |

### 핵심 결정과 이유 (급소만)

**① 왜 WSL2인가**
판단 기준을 ⓐ 유닉스 권한·명령 실습이 실제로 가능할 것 ⓑ 추가 설치·전환 비용이 낮을 것 ⓒ 이후 리눅스 학습과 환경이 이어질 것, 세 가지로 두었다. 후보는 (A) WSL2 (B) 별도 리눅스 VM (C) 이중 부팅이었는데, B·C는 설치·전환 비용이 크고 윈도우 작업 흐름이 끊긴다. WSL2는 윈도우 안에서 리눅스 셸을 그대로 쓰면서 세 기준을 모두 충족해 선택했다.

**② 왜 작업 폴더를 `/mnt/c`가 아닌 리눅스 홈(`~`)에 두는가**
`/mnt/c`(윈도우 디스크) 밑은 NTFS라 `chmod`로 바꾼 권한이 제대로 반영되지 않는다. 권한 실습(755/644)이 성립하려면 리눅스 네이티브 파일시스템인 홈 디렉토리에서 작업해야 하므로, 모든 실습을 `~/codyssey-dev-workstation`에서 수행했다.

---

## 3. 수행 체크리스트

- [x] 터미널 기본 조작 (위치/목록(숨김)/이동/생성/복사/이름변경/삭제/내용확인/빈파일)
- [x] 파일·디렉토리 권한 변경 실습 (전/후 비교)
- [x] Docker 설치·점검 (`docker --version`, `docker info`)
- [x] Docker 운영 명령 (`images`, `ps -a`, `logs`, `stats`)
- [x] `hello-world` 실행
- [x] `ubuntu` 컨테이너 진입 + attach/exec 차이 관찰
- [x] Dockerfile 기반 커스텀 이미지 빌드·실행
- [x] 포트 매핑 접속 (8080 / 8081)
- [x] 바인드 마운트 반영 (호스트 변경 전/후)
- [x] 볼륨 영속성 (컨테이너 삭제 전/후 데이터 유지)
- [x] Git 설정 + GitHub/VSCode 연동
- [x] (보너스) Docker Compose 단일 서비스

---

## 4. 수행 로그 & 증거

> 명령과 출력을 함께 싣는다.

### 4-1. 터미널 기본 조작

```bash
$ cd ~/codyssey-dev-workstation
$ mkdir practice && cd practice
$ pwd
/home/jeilie0605/codyssey-dev-workstation/practice
$ touch empty.txt                      # 빈 파일 생성
$ echo "hello codyssey" > a.txt        # 내용 넣어 생성
$ cat a.txt
hello codyssey
$ ls -a                                # 숨김 포함 목록
.  ..  a.txt  empty.txt
$ cp a.txt b.txt                       # 복사
$ mv b.txt c.txt                       # 이름변경(이동)
$ ls -a
.  ..  a.txt  c.txt  empty.txt
$ rm c.txt                             # 삭제
$ ls -a
.  ..  a.txt  empty.txt
```

- **절대경로 vs 상대경로**: `cd ~/codyssey-dev-workstation`(절대, `~`부터 전체 경로라 어디서 쳐도 같은 곳) ↔ `cd practice`(상대, 현재 위치 기준).

### 4-2. 파일 권한 실습 (전/후 비교)

```bash
$ touch perm.txt
$ mkdir permdir
$ ls -l            # ① 변경 전 (기본값: 파일 644, 디렉토리 755)
-rw-r--r-- 1 jeilie0605 jeilie0605   15 Nov  2 21:16 a.txt
-rw-r--r-- 1 jeilie0605 jeilie0605    0 Nov  2 21:16 empty.txt
-rw-r--r-- 1 jeilie0605 jeilie0605    0 Nov  2 21:18 perm.txt
drwxr-xr-x 2 jeilie0605 jeilie0605 4096 Nov  2 21:18 permdir

$ chmod 600 perm.txt
$ chmod 700 permdir
$ ls -l            # ② 변경 후
-rw------- 1 jeilie0605 jeilie0605    0 Nov  2 21:18 perm.txt
drwx------ 2 jeilie0605 jeilie0605 4096 Nov  2 21:18 permdir
```

- **읽는 법**: 맨 앞 1칸은 종류(`-` 파일 / `d` 디렉토리), 이후 `rwx`가 소유자·그룹·기타 3묶음.
- **숫자 규칙**: `r=4, w=2, x=1`의 합. `644`=`rw-`(6)`r--`(4)`r--`(4), `755`=`rwx`(7)`r-x`(5)`r-x`(5), `600`=`rw-`(6)`---`(0)`---`(0), `700`=`rwx`(7)`---`(0)`---`(0).
- 디렉토리에서 `x`는 "그 안에 들어갈(`cd`) 수 있음"을 뜻한다.

📷 `docs/img/perm-before-after.png` (전/후 `ls -l` 한 화면)

### 4-3. Docker 설치·점검

```bash
$ docker --version
Docker version 29.9.2, build a82e528

$ docker info
# ... (Client 생략) ...
Server:
 Server Version: 29.9.2
 Storage Driver: overlayfs
 Cgroup Version: 2
 Kernel Version: 6.18.54.1-microsoft-standard-WSL2
 Operating System: Docker Desktop
 OSType: linux
 Architecture: x86_64
 Name: docker-desktop
```

- `Server:` 섹션이 에러 없이 나왔다 = **Docker 데몬 연결 성공**(점검의 핵심).

📷 `docs/img/docker-info.png`

### 4-4. 이미지 다운로드 & 운영 명령 (`images` / `ps -a` / `logs` / `stats`)

```bash
$ docker images
IMAGE                ID             DISK USAGE   CONTENT SIZE
my-web:1.0           8a3194a5cd32       93.6MB         26.3MB
ubuntu:latest        6a06111c3b0a        163MB         45.9MB
hello-world:latest   c567b231f656       25.9kB         9.49kB

$ docker ps                      # 실행 중 컨테이너
$ docker ps -a                   # 종료된 것 포함 전체
$ docker logs my-web-8080        # 컨테이너 로그 (아래 4-8 참조)
$ docker stats --no-stream       # 리소스 사용량 스냅샷 (아래 4-8 참조)
```

### 4-5. `hello-world` 실행

```bash
$ docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.
# Docker took: 1) client→daemon  2) daemon이 Hub에서 image pull
#              3) 그 image로 container 생성·실행  4) 출력 스트리밍

$ docker ps -a
CONTAINER ID   IMAGE         COMMAND    STATUS                    NAMES
78b271e2efc2   hello-world   "/hello"   Exited (0) ...            reverent_euler
```

- **이미지 vs 컨테이너**: 이미지 = 실행에 필요한 걸 담은 읽기전용 **템플릿(설계도)**, 컨테이너 = 그 이미지를 실제로 **실행한 인스턴스**. (붕어빵 틀 vs 구워진 붕어빵)

### 4-6. `ubuntu` 컨테이너 — attach vs exec

```bash
# ── 6-1. 직접 들어가서 exit → 컨테이너 종료 ──
$ docker run -it --name ub1 ubuntu bash
root@0708fa26fa34:/# ls
bin  boot  dev  etc  home ... usr  var
root@0708fa26fa34:/# echo "hello from ubuntu container"
hello from ubuntu container
root@0708fa26fa34:/# exit
$ docker ps -a
0708fa26fa34   ubuntu   "bash"   Exited (0)   ub1      # ← 메인 프로세스(bash) 종료 → 컨테이너 종료

# ── 6-2. -dit로 띄우고 exec로 들어갔다 exit → 컨테이너 유지 ──
$ docker run -dit --name ub2 ubuntu
$ docker exec -it ub2 bash
root@098a999020fc:/# echo "this is an exec session"
root@098a999020fc:/# exit
$ docker ps
098a999020fc   ubuntu   "/bin/bash"   Up 9 seconds   ub2   # ← exec는 추가 프로세스라 본체 유지
```

- **attach** = 컨테이너의 메인 프로세스(PID 1)에 붙음 → 거기서 `exit`하면 컨테이너도 종료.
- **exec** = 실행 중 컨테이너에 새 프로세스를 띄움 → 나가도 컨테이너 유지. 살아있는 컨테이너에 잠깐 들어갈 땐 `exec`가 안전.

### 4-7. Dockerfile 기반 커스텀 이미지

**선택한 베이스**: `nginx:alpine` (웹서버가 내장된 초경량 리눅스 이미지). 맨땅이 아니라 완성된 토대 위에서 시작하려고 선택.

```dockerfile
FROM nginx:alpine
LABEL org.opencontainers.image.title="codyssey-custom-nginx"
ENV APP_ENV=dev
COPY site/ /usr/share/nginx/html/
```

**커스텀 포인트와 목적**
- `FROM nginx:alpine` — nginx 웹서버가 설치된 베이스 지정.
- `LABEL ...title=...` — 이미지 메타데이터(제목) 부여.
- `ENV APP_ENV=dev` — 환경변수 주입(설정과 코드 분리 맛보기).
- `COPY site/ /usr/share/nginx/html/` — 내 정적 콘텐츠를 nginx 기본 웹루트로 복사해 **기본 페이지를 내 페이지로 교체**.

```bash
$ docker build -t my-web:1.0 .
 => [1/2] FROM docker.io/library/nginx:alpine ...
 => [2/2] COPY site/ /usr/share/nginx/html/
 => naming to docker.io/library/my-web:1.0
[+] Building 8.4s (7/7) FINISHED

$ docker images
my-web:1.0   8a3194a5cd32   93.6MB   26.3MB      # ← 내 커스텀 이미지 생성 확인
```

### 4-8. 포트 매핑 접속 (8080 / 8081)

```bash
$ docker run -d -p 8080:80 --name my-web-8080 my-web:1.0
$ docker run -d -p 8081:80 --name my-web-8081 my-web:1.0
$ docker ps
CONTAINER ID   IMAGE        PORTS                                     NAMES
ba716974af6f   my-web:1.0   0.0.0.0:8081->80/tcp, [::]:8081->80/tcp   my-web-8081
4bf5505f9e4d   my-web:1.0   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   my-web-8080

$ curl http://localhost:8080
<!DOCTYPE html>
<html lang="ko">
...
  <h1>Hello from my custom nginx container</h1>
  <p>Codyssey 과제 - Dockerfile 커스텀 이미지</p>
...
```

- `-p 8080:80` = **호스트 8080 ↔ 컨테이너 80**(nginx가 듣는 포트) 연결. 컨테이너는 격리된 네트워크라 **이 매핑이 없으면 바깥에서 접근 불가** → 포트 매핑이 필요한 이유.

📷 `docs/img/browser-8080.png` (주소창 `localhost:8080` + 응답 화면)
📷 `docs/img/browser-8081.png` (선택)

**운영 명령 증거 (logs / stats)**

```bash
$ docker logs my-web-8080
...
172.17.0.1 - - [02/Nov/2026:12:37:14 +0000] "GET / HTTP/1.1" 200 237 "-" "curl/8.18.0" "-"

$ docker stats --no-stream
CONTAINER ID   NAME          CPU %   MEM USAGE / LIMIT     MEM %   PIDS
d5860cf8b545   my-web-8081   0.00%   11.93MiB / 7.419GiB   0.16%   13
e06e0fc1dc83   my-web-8080   0.00%   11.07MiB / 7.419GiB   0.15%   13
```

### 4-9. 바인드 마운트 (호스트 변경 즉시 반영)

```bash
$ docker run -d -p 8082:80 --name my-web-bind -v "$(pwd)/site":/usr/share/nginx/html my-web:1.0

$ curl http://localhost:8082            # ① 변경 전
...<p>Codyssey 과제 - Dockerfile 커스텀 이미지</p>...

$ echo '  <p>바인드 마운트 테스트 - 호스트에서 수정함 (재빌드 없음)</p>' >> site/index.html

$ curl http://localhost:8082            # ② 변경 후
...<p>Codyssey 과제 - Dockerfile 커스텀 이미지</p>
  <p>바인드 마운트 테스트 - 호스트에서 수정함 (재빌드 없음)</p>    # ← 추가한 줄이 바로 반영
```

- **바인드 마운트**(`-v 호스트경로:컨테이너경로`) = 호스트 폴더를 컨테이너에 실시간 연결. 호스트 수정이 **재빌드/재시작 없이** 즉시 반영된다. 반대로 `COPY`는 이미지에 구워버려 고치려면 재빌드해야 한다.

### 4-10. 볼륨 영속성 (컨테이너 삭제 후에도 데이터 유지)

```bash
$ docker volume create mydata
$ docker volume ls
DRIVER    VOLUME NAME
local     mydata

$ docker run -d --name vol-test -v mydata:/data ubuntu sleep infinity
$ docker exec vol-test bash -c "echo 'persisted hello from codyssey' > /data/hello.txt && cat /data/hello.txt"
persisted hello from codyssey

$ docker rm -f vol-test                                  # 컨테이너 통째로 삭제

$ docker run -d --name vol-test2 -v mydata:/data ubuntu sleep infinity
$ docker exec vol-test2 cat /data/hello.txt
persisted hello from codyssey                            # ← 삭제 후 새 컨테이너에서도 데이터 유지
```

- **볼륨** = Docker가 관리하는 별도 저장소. 컨테이너 수명과 **분리**돼 있어 컨테이너를 지워도 데이터가 남는다 → DB 같은 **영속 데이터**용. (바인드 마운트=내가 아는 호스트 폴더 / 볼륨=Docker 관리 영역)

### 4-11. (보너스) Docker Compose 단일 서비스

```yaml
# docker-compose.yml
services:
  web:
    build: .
    ports:
      - "8083:80"
    environment:
      - APP_ENV=prod
```

```bash
$ docker compose up -d
 ✔ Image codyssey-dev-workstation-web   Built
 ✔ Network ..._default                  Created
 ✔ Container ...-web-1                   Started
$ docker compose ps
NAME                             SERVICE   STATUS         PORTS
codyssey-dev-workstation-web-1   web       Up ...         0.0.0.0:8083->80/tcp
$ curl http://localhost:8083     # 내 페이지 응답 확인
$ docker compose down
 ✔ Container ...-web-1   Removed
 ✔ Network ..._default  Removed
```

- **배움 포인트**: 긴 `docker run -d -p ... -e ...` 명령이 **설정 파일 한 장**이 된다. 누가 받아도 `docker compose up` 한 줄로 똑같이 재현 → 실행 명령이 "문서화된 실행 설정"으로 바뀌는 것.

### 4-12. Git 설정 + GitHub / VSCode 연동

```bash
$ git config --global user.name "QWERQWER-qwer"
$ git config --global user.email "***마스킹***"
$ git config --global init.defaultBranch main
$ git config --list
user.name=QWERQWER-qwer
user.email=***마스킹***
init.defaultbranch=main
```

- `user.name/email` = 커밋에 박히는 신원(로컬 Git). `init.defaultBranch main` = 새 레포 기본 브랜치를 `main`으로.
- VSCode를 **WSL 원격 모드**(`WSL: Ubuntu`)로 열어 레포를 연동하고, GitHub 계정으로 로그인했다.

📷 `docs/img/git-config.png` (이메일 마스킹)
📷 `docs/img/vscode-wsl.png` (WSL 연결)
📷 `docs/img/vscode-github-login.png` (GitHub 로그인 상태)

> **Git vs GitHub**: Git = 내 컴퓨터에서 버전을 관리하는 도구(로컬). GitHub = 그 저장소를 원격에 올려 공유·협업하는 플랫폼. `git clone`/`push`가 둘을 잇는다.

---

## 5. 트러블슈팅

### #1 WSL 설치 후에도 배포판이 없음
- **문제**: `wsl --install` 완료 후 `wsl -l -v`에 설치된 배포판이 없다고 나옴.
- **원인 가설**: `wsl --install`이 WSL 플랫폼(기능)만 활성화하고, 리눅스 배포판은 따로 설치해야 하는 상태.
- **확인**: `wsl -l -v` 출력에 NAME 없음 / "설치된 배포가 없습니다".
- **해결**: `wsl --install -d Ubuntu`로 Ubuntu를 명시 설치 → `Ubuntu  Stopped  2` 확인.

### #2 리눅스 명령을 PowerShell에서 실행해 동작하지 않음
- **문제**: `cd ~`, `docker` 등을 쳤는데 인식이 안 되거나 엉뚱하게 동작.
- **원인 가설**: 윈도우 PowerShell과 WSL Ubuntu 셸을 혼동 — 리눅스 명령을 PowerShell에서 실행.
- **확인**: 프롬프트가 `PS C:\...>`(PowerShell)인지 `jeilie0605@Yi-mi:~$`(Ubuntu)인지로 구분됨.
- **해결**: 과제의 모든 CLI 작업을 Ubuntu 셸에서 수행하기로 통일. (설치류 명령만 PowerShell)

---

## 6. 한계 (구현 / 미구현)

- **구현**: 터미널 기본 조작, 파일/디렉토리 권한 실습, Docker 설치·점검 및 운영 명령, hello-world/ubuntu 컨테이너(attach·exec), Dockerfile 커스텀 이미지, 포트 매핑(2포트), 바인드 마운트, 볼륨 영속성, Git·GitHub·VSCode 연동, Docker Compose 단일 서비스까지 수행하고 명령·출력으로 기록했다.
- **미구현**: Compose 멀티 컨테이너·서비스 디스커버리, SSH 키 인증(현재 HTTPS 사용)은 범위상 수행하지 않았다. 다음 과제의 확장 목표로 둔다.
- **환경 종속**: 본 기록은 Windows 11 + WSL2 기준이다. macOS/Linux에서는 §2 설치 절차만 다르고, 이후 `docker`/`git` 명령은 동일하게 재현된다. 권한 실습은 반드시 리눅스 네이티브 파일시스템(홈)에서 수행해야 한다(§핵심 결정 ②).
