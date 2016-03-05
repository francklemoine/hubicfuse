# HubiC

This Docker image aims to mount a [HubiC](https://hubic.com/) data store to backup/restore files.
It uses [hubicfuse](https://github.com/TurboGit/hubicfuse).

The idea is to mount, backup or restore datas and then exits.

Storage of datas into HubiC is in :

- Normal mode (using rsync tool)
- Encrypt mode (using duplicity tool)
  - to avoid error (Fatal Error: Backup source host has changed), the container hostname has to be constant.
  - default retention is 2 months


A Dockerfile is also available for the __Raspberry Pi__ since there are specifics rules on this platform
(Automated builds fail since Docker Hub currently doesn't support ARM platforms).
You can grab that image or build it yourself from Github.

## Links

- arm (raspberry PI)
  - [GitHub](https://github.com/francklemoine/rpi-hubicfuse)
  - [Docker Hub](https://hub.docker.com/flem/rpi-hubicfuse)

- x86_64
  - [GitHub](https://github.com/francklemoine/hubicfuse)
  - [Docker Hub](https://hub.docker.com/flem/hubicfuse)


## Usage


### Inline Help

```
docker run -ti --rm flem/hubicfuse --help
```


### get token

First, you need to retrieve the token to make /root/.hubicfuse file

```
docker run -ti --rm flem/hubicfuse --get_token
```


### mount only (/mnt/hubic)

```
docker run -ti --rm \
           --cap-add SYS_ADMIN \
           --device /dev/fuse \
           flem/hubicfuse --mount --id XXXX --secret XXXX --token XXXX
```


### backup (normal mode using rsync)

```
docker run --rm \
           --cap-add SYS_ADMIN \
           --device /dev/fuse \
           --volume /path/to/mydatas:/mydatas:ro \
           flem/hubicfuse --backup --id XXXX --secret XXXX --token XXXX --hubic_dir default/path/to/backup
```


### restore (normal mode using rsync)

```
docker run --rm \
           --cap-add SYS_ADMIN \
           --device /dev/fuse \
           --volume /path/to/mydatas:/mydatas \
           flem/hubicfuse --restore --id XXXX --secret XXXX --token XXXX --hubic_dir default/path/to/backup
```


### backup (encrypt mode using duplicity)

#### full backup

```
docker run --rm \
           --cap-add SYS_ADMIN \
           --device /dev/fuse \
           --volume /path/to/mydatas:/mydatas:ro \
           --hostname MYHOST \
           flem/hubicfuse --backup --id XXXX --secret XXXX --token XXXX --hubic_dir default/path/to/backup \
                          --crypt --passphrase "XXXX" --mode full --retention 2
```

#### incremental backup

```
docker run --rm \
           --cap-add SYS_ADMIN \
           --device /dev/fuse \
           --volume /path/to/mydatas:/mydatas:ro \
           --hostname MYHOST \
           flem/hubicfuse --backup --id XXXX --secret XXXX --token XXXX --hubic_dir default/path/to/backup \
                          --crypt --passphrase "XXXX" --mode incr --retention 2
```


### restore (encrypt mode using duplicity)

```
docker run --rm \
           --cap-add SYS_ADMIN \
           --device /dev/fuse \
           --volume /path/to/mydatas:/mydatas:ro \
           --hostname MYHOST \
           flem/hubicfuse --backup --id XXXX --secret XXXX --token XXXX --hubic_dir default/path/to/backup \
                          --crypt --passphrase "XXXX"
```





