#!/bin/bash
. /wikk/etc/wikk.conf

#No longer produce wikk.fdf files. We generate hourly ones directly
#if [ -f ${NTM_LOG_DIR}/wikk.fdf ] ; then
 #This will start a new log.
# /bin/mv ${NTM_LOG_DIR}/wikk.fdf ${NTM_LOG_DIR}/wikk.`date "+%Y-%m-%d_%H:%M:%S"`.fdf
#fi

#Remove anything older than 14 days, as it should have been processed well before then
/usr/bin/find ${NTM_LOG_DIR} -maxdepth 1 -mtime +31 -name wikk\*  -exec /bin/rm -f {} \;
