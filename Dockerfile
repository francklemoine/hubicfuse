# DESCRIPTION:        Backup/Restore Hubic Space within a container
# BUILD:              docker build -t flem/hubicfuse .
#
# GET TOKEN:          docker run -ti --rm \
#                                flem/hubicfuse --get_token
# MOUNT HUBIC SPACE:  docker run -ti --rm \
#                                --cap-add SYS_ADMIN
#                                --device /dev/fuse
#                                flem/hubicfuse --mount --id XXXX --secret XXXX --token XXXX
#
# BACKUP:             docker run --rm \
#                                --cap-add SYS_ADMIN
#                                --device /dev/fuse
#                                -v /path/to/mydatas:/mydatas:ro
#                                flem/hubicfuse --backup --id XXXX --secret XXXX --token XXXX --hubic_dir default/music
#
# RESTORE:            docker run --rm \
#                                --cap-add SYS_ADMIN
#                                --device /dev/fuse
#                                -v /path/to/mydatas:/mydatas
#                                flem/hubicfuse --restore --id XXXX --secret XXXX --token XXXX --hubic_dir default/music


FROM debian:jessie
MAINTAINER Franck Lemoine <franck.lemoine@flem.fr>

# properly setup debian sources
ENV DEBIAN_FRONTEND=noninteractive

RUN buildDeps=' \
		build-essential \
		pkg-config \
		unzip \
		wget \
	' \
	set -x \
	&& apt-get -y update \
	&& apt-get -y upgrade \
	&& apt-get install -y --no-install-recommends libcurl4-openssl-dev libxml2-dev libssl-dev libfuse-dev libjson0-dev libmagic-dev curl ca-certificates rsync duplicity $buildDeps \
	&& cd /tmp \
	&& wget https://github.com/TurboGit/hubicfuse/archive/master.zip -P /tmp \
	&& unzip /tmp/master.zip \
	&& cd /tmp/hubicfuse-master \
	&& ./configure \
	&& make; make install \
	&& cp hubic_token /usr/local/bin \
	&& chmod +x /usr/local/bin/hubic_token \
	&& mkdir /mnt/hubic \
	&& mkdir /mydatas \
	&& apt-get purge -y --auto-remove $buildDeps \
	&& apt-get clean autoclean \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /tmp/*

COPY docker-entrypoint.sh /

RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
