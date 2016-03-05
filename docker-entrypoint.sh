#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="${BASH_SOURCE[0]##*/}"
__bas0="${__base%.sh}"

MY_HUBIC_ID=""
MY_HUBIC_SECRET=""
MY_HUBIC_TOKEN=""
MY_HUBIC_DIR=""
MY_RSYNC_EXTRAS=""
MY_DUPL_PASS=""
MY_DUPL_MODE="full"
MY_DUPL_RETN="2"

HUBIC_CONFFILE="/root/.hubicfuse"
HUBIC_MOUNTPOINT="/mnt/hubic"
LOCAL_DATAS_DIR="/mydatas"

DO_MOUNT=false
DO_BACKUP=false
DO_RESTORE=false
DO_ENCRYPT=false


function usage() {
	cat <<-EOF
	usage: ${__base} command [ opts ]

	  STANDARD COMMANDS
	    -h,--help        : this (help) message
	    -g,--get_token   : get refresh token = f(client_id, client_secret, redirect_uri)
	                         run /usr/local/bin/hubic_token
	    -m,--mount       : mount hubic file system (/mnt/hubic)
	    -b,--backup      : save from /mydatas to /mnt/hubic/hubic_dir
	    -r,--restore     : restore from /mnt/hubic/hubic_dir to /mydatas


	  STANDARD OPTIONS (mandatory with mount/backup/restore commands)
	    -i,--id  arg     : hubic client_id
	                         cf. https://hubic.com/home/browser/developers/
	                       mandatory with mount/backup/restore commands (first run)
	    -s,--secret arg  : hubic client_secret
	                         cf. https://hubic.com/home/browser/developers/
	                       mandatory with mount/backup/restore commands (first run)
	    -t,--token arg   : hubic refresh_token
	                         retrieve with 'get_token' command before
	                         mandatory with mount/backup/restore commands (first run)
	    --hubic_dir arg  : hubic directory, relative to the mount point (backup/restore)


	  NON-ENCRYPT OPTIONS (based on 'rsync' tool)
	    --rsync-extras   : rsync extra parameters


	  ENCRYPT OPTIONS (based on 'duplicity' tool)
	    --crypt          : crypt backup/restore
	    --passphrase arg : passphrase
	    --mode arg       : full/incr (default=full)
	    --retention arg  : delete backups older than this time (in months) (default=2) 

	EOF
	exit 0
}



function parse_args() {
	OPTS=$(getopt -o hgmbri:s:t: --long help,get_token,mount,backup,restore,id:,secret:,token:,hubic_dir:,rsync-extras:,crypt,passphrase:,mode:,retention: -n 'parse-options' -- "$@")
	if [ $? != 0 ] ; then echo "Failed parsing options."; exit 1 ; fi
	eval set -- "$OPTS"

	while true; do
		case "$1" in
			-h|--help)      usage; shift ;;
			-g|--get_token) get_refresh_token; shift ;;
			-m|--mount)     DO_MOUNT=true; shift ;;
			-b|--backup)    DO_BACKUP=true; shift ;;
			-r|--restore)   DO_RESTORE=true; shift ;;
			-c|--crypt)     DO_ENCRYPT=true; shift ;;
			-i|--id )       MY_HUBIC_ID="$2"; shift 2 ;;
			-s|--secret)    MY_HUBIC_SECRET="$2"; shift 2 ;;
			-t|--token)     MY_HUBIC_TOKEN="$2"; shift 2 ;;
			--rsync-extras) MY_RSYNC_EXTRAS="$2"; shift ;;
			--hubic_dir)    MY_HUBIC_DIR="$2"; shift 2 ;;
			--passphrase)   MY_DUPL_PASS="$2"; shift 2 ;;
			--mode)         MY_DUPL_MODE="$2"; shift 2 ;;
			--retention)    MY_DUPL_RETN="$2"; shift 2 ;;
			--)             shift; break ;;
			*)              break ;;
		esac
	done
}



function get_refresh_token() {
	/usr/local/bin/hubic_token
	exit 0
	## root@f287bfefbb00:~# /usr/local/bin/hubic_token
	## client_id (the app's id): XXXXXXXXXX
	## client_secret (the app's secret): XXXXXXXXXX
	## redirect_uri (declared at app's creation): XXXXXXXXXX
	## 
	## For the scope -what you authorize your app to do-, enter characters as suggested
	## in parenthesis, or just hit return if you don't need the item authorized.
	## Get account usage (r): r
	## Get all published links in one call (r): r
	## Get OpenStack credentials, eg. access to your files (r): r
	## Send activation email (w): w
	## Add new/Get/Delete published link (wrd): wrd
	## 
	## user_login (the e-mail you used to subscribe): XXXXXXXXXX
	## user_pwd (your hubiC's main password): XXXXXXXXXX
	## 
	## Success!
	## 
	## 
	## # Here is what your app needs to connect to hubiC:
	## client_id=XXXXXXXXXX
	## client_secret=XXXXXXXXXX
	## refresh_token=XXXXXXXXXX
}



function check_args() {
	if is_file ${HUBIC_CONFFILE}; then
		[[ -n "${MY_HUBIC_ID}" ]]     && echo "existing file ${HUBIC_CONFFILE}, ignoring hubic client_id argv"
		[[ -n "${MY_HUBIC_SECRET}" ]] && echo "existing file ${HUBIC_CONFFILE}, ignoring hubic client_secret argv"
		[[ -n "${MY_HUBIC_TOKEN}" ]]  && echo "existing file ${HUBIC_CONFFILE}, ignoring hubic refresh_token argv"
	else
		[[ -z "${MY_HUBIC_ID}" ]]     && ( echo "hubic client_id: mandatory argv";     exit 1; )
		[[ -z "${MY_HUBIC_SECRET}" ]] && ( echo "hubic client_secret: mandatory argv"; exit 1; )
		[[ -z "${MY_HUBIC_TOKEN}" ]]  && ( echo "hubic refresh_token: mandatory argv"; exit 1; )
		echo -e "client_id=${MY_HUBIC_ID}\nclient_secret=${MY_HUBIC_SECRET}\nrefresh_token=${MY_HUBIC_TOKEN}" >${HUBIC_CONFFILE}
	fi

	if ${DO_BACKUP} || ${DO_RESTORE}; then
		if [[ -z "${MY_HUBIC_DIR}" ]]; then
			echo "hubic subdirectory: mandatory argv"
			exit 1
		fi
		${DO_BACKUP}  && echo "backup to hubic"
		${DO_RESTORE} && echo "restore from hubic"
		if ${DO_ENCRYPT}; then
			if [[ ! "${MY_DUPL_MODE,,}" =~ ^(full|incr)$ ]]; then
				MY_DUPL_MODE="full"
			fi
			if [[ ! "${MY_DUPL_RETN,,}" =~ ^[1-9][0-9]?$ ]]; then
				MY_DUPL_RETN="2"
			fi
			[[ -z "${MY_DUPL_PASS}" ]] && ( echo "duplicity crypt passphrase: mandatory argv"; exit 1; )
			export PASSPHRASE=${MY_DUPL_PASS}
		fi
	fi
}



function hubic_mount() {
	local command="hubicfuse ${HUBIC_MOUNTPOINT} -o noauto_cache,sync_read,allow_other"

	echo "mount: $command"
	$command
	return $?
}



function hubic_backup() {
	local command1="rsync -rv ${MY_RSYNC_EXTRAS} ${LOCAL_DATAS_DIR}/ ${HUBIC_MOUNTPOINT}/${MY_HUBIC_DIR}"
	local command2=""
	if ${DO_ENCRYPT}; then
		command1="duplicity ${MY_DUPL_MODE} ${LOCAL_DATAS_DIR}/ file://${HUBIC_MOUNTPOINT}/${MY_HUBIC_DIR}/"
		command2="duplicity remove-older-than ${MY_DUPL_RETN}M file://${HUBIC_MOUNTPOINT}/${MY_HUBIC_DIR}/ --force"
	fi

	hubic_mount || ( echo "hubic mount error"; exit 1; )
	mkdir -p ${HUBIC_MOUNTPOINT}/${MY_HUBIC_DIR}
	echo "backup: ${command1}"
	${command1}
	if [[ -n "${command2}" ]]; then
		echo "delete: ${command2}"
		${command2}
	fi
}



function hubic_restore() {
	local command="rsync -rv ${MY_RSYNC_EXTRAS} ${HUBIC_MOUNTPOINT}/${MY_HUBIC_DIR}/ ${LOCAL_DATAS_DIR}"
	if ${DO_ENCRYPT}; then
		command="duplicity restore file://${HUBIC_MOUNTPOINT}/${MY_HUBIC_DIR}/ ${LOCAL_DATAS_DIR}/"
	fi

	hubic_mount || ( echo "hubic mount error"; exit 1; )
	echo "restore: $command"
	$command
}



function is_file() {
	local f="$1"
	[[ -f "$f" ]] && return 0 || return 1
}



function is_int() {
	return $(test "$@" -eq "$@" > /dev/null 2>&1);
}



parse_args "$@"
check_args

echo "start $(date)"
if ${DO_MOUNT}; then
	hubic_mount
	bash
	echo "syncing..."; sync
	echo "unmounting..."; umount ${HUBIC_MOUNTPOINT}
elif ${DO_BACKUP}; then
	hubic_backup
elif ${DO_RESTORE}; then
	hubic_restore
fi
echo "end $(date)"

