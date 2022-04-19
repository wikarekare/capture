#!/bin/sh
. /wikk/etc/wikk.conf

#logs are in ${FLOW_LOG_DIR}/log/year/year-month/year-month-day/
dir_today_4=`date -v "-4d" "+%Y/%Y-%m/%Y-%m-%d"`
dir_today_3=`date -v "-3d" "+%Y/%Y-%m/%Y-%m-%d"`
dir_today_2=`date -v "-2d" "+%Y/%Y-%m/%Y-%m-%d"`
dir_today_1=`date -v "-1d" "+%Y/%Y-%m/%Y-%m-%d"`
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


