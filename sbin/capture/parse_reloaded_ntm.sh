#!/bin/bash
. /wikk/etc/wikk.conf

for i in ${TMP_DIR}/ntm/*.fdf.out
do
if( test ! -e ${i}.summary -o ${i} -nt ${i}.summary )
then
	${TOUCH} -r $i ${i}.summary
        ${SBIN_DIR}/capture/parse_ntm_log.rb ${i}
	${TOUCH} -r $i ${i}_10.summary
fi
done
