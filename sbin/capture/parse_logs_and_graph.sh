#!/bin/sh
. /wikk/etc/wikk.conf

LOCK_PID_FILE=${TMP_DIR}/parse_ip_logs.lock
${LOCKFILE} ${LOCK_PID_FILE} $$
if [ $? != 0 ] ; then  exit 0 ; fi

${SBIN_DIR}/capture/isnewer.sh
${SBIN_DIR}/capture/parse_ntm.sh
${SBIN_DIR}/account/sqlgraphMonth.sh

${RM} -f ${LOCK_PID_FILE}

