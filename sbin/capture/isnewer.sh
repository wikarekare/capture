#!/bin/bash
. /wikk/etc/wikk.conf

#logs are in ${FLOW_LOG_DIR}/log/year/year-month/year-month-day/
if [ "${OSTYPE}" = "FreeBSD" ] ; then
  dir_today_4=`date -v "-4d" "+%Y/%Y-%m/%Y-%m-%d"`
  dir_today_3=`date -v "-3d" "+%Y/%Y-%m/%Y-%m-%d"`
  dir_today_2=`date -v "-2d" "+%Y/%Y-%m/%Y-%m-%d"`
  dir_today_1=`date -v "-1d" "+%Y/%Y-%m/%Y-%m-%d"`
else
  dir_today_4=`date "+%Y/%Y-%m/%Y-%m-%d" -d "4 days ago"`
  dir_today_3=`date "+%Y/%Y-%m/%Y-%m-%d" -d "3 days ago"`
  dir_today_2=`date "+%Y/%Y-%m/%Y-%m-%d" -d "2 days ago"`
  dir_today_1=`date "+%Y/%Y-%m/%Y-%m-%d" -d "1 days ago"`
fi
dir_today=`date "+%Y/%Y-%m/%Y-%m-%d"`


#Catch up with remainder of yesterdays logs (after we cross the day boundary)
#If we miss a day, then we need to manually go back.
#
${SBIN_DIR}/capture/isnewer_flow.rb ${FLOW_LOG_DIR}/log/$dir_today_4
${SBIN_DIR}/capture/isnewer_flow.rb ${FLOW_LOG_DIR}/log/$dir_today_3
${SBIN_DIR}/capture/isnewer_flow.rb ${FLOW_LOG_DIR}/log/$dir_today_2
${SBIN_DIR}/capture/isnewer_flow.rb ${FLOW_LOG_DIR}/log/$dir_today_1
#process todays logs.
${SBIN_DIR}/capture/isnewer_flow.rb ${FLOW_LOG_DIR}/log/$dir_today
