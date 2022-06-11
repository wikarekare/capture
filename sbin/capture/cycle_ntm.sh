#!/bin/sh
. /wikk/etc/wikk.conf

#No longer produce wikk.fdf files. We generate hourly ones directly
#if [ -f ${NTM_LOG_DIR}/wikk.fdf ] ; then
 #This will start a new log.
# /bin/mv ${NTM_LOG_DIR}/wikk.fdf ${NTM_LOG_DIR}/wikk.`date "+%Y-%m-%d_%H:%M:%S"`.fdf
#fi

#Remove anything older than 14 days, as it should have been processed well before then
/usr/bin/find ${NTM_LOG_DIR} -mtime +31d -name wikk\* -maxdepth 1 -exec /bin/rm -f {} \;

