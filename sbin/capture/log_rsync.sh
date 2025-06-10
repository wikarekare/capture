#!/bin/bash
# Resync the logs from the Active to the standby server
# Wouldn't normally be used.

. /wikk/etc/wikk.conf
DEST=db1
YEAR=$(date +%Y)

LOCK_PID_FILE=${TMP_DIR}/flow_rsync.lock
${LOCKFILE} ${LOCK_PID_FILE} $$
if [ $? != 0 ] ; then  exit 0 ; fi

rsync -rltgoD --chmod=o-t --exclude 'tmp*' ${FLOW_LOG_DIR}/log/${YEAR}/ root@${DEST}:${FLOW_LOG_DIR}/log/flow/log/

${RM} -f ${LOCK_PID_FILE}
