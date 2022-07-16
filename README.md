# Capture

Scripts to parse the flow tools logs, per site network, storing the results in the WIKK DB

We were using Netramet to log traffic. Now we are using Softflow, sending data to flow-tools in Netflow format.  Flow-tools has a binary storage format, cycling the log files every 5m. Netramet's log was text based, and we cycled the logs every hour.

We had existing log processing scripts for Netramet, so as a quick hack, a conversion program is run to generate a temporary Netramet style log, from the flow-tools logs.

## source file from  flow-tools
We have altered Softflow to use the 'saa' and 'daa' fields to record part of the layer 2 packet MAC addresses, rather than the autonomous system numbers. We can then tell which outgoing modem was used to route the packets, which helps with monitoring.

Flow-tools Netflow logs store:
* start and end times recorded to microseconds
* Intervals are not uniform.
* You can get multiple records for the same stream, in the same interval.
* Log uses last two bytes of source and destination adjacent MAC addresses from data link layer into saa and daa Autonomous System fields.

NeTraMet:
* Only records a start time in seconds (Fixed interval implies the end time)
* Interval time is fixed (10s), rather than different intervals
* A single record records both in and out for a host to host flow in this 10s interval.
* Records MAC addresses of source and destination (next router), so we can tell which path the packets took.

Key differences between flow-tool' Netflow logs and Netramet logs, is the sample times.

* The flow-tools interval is random. To convert these to fixed interval Netramet log entries, we assume the traffic was uniform between the log record's start and end interval.
* Flowtools has multiple records per interval, for the same flow. To convert to Netramets single flow record, we need to merge multiple flow-tools log entries (having first done an interval conversion)
* The partial (2 byte) MAC addresses in the flow record are converted to full MAC addresses in the Netramet log entries.


```
# flow-cat ft-v05.2013-12-15.162002+1300 | flow-print -f 25
#   0                      1                       2     3            4    5     6            7      8  9   10   11   12
#   #Start	               End	                   Sif	SrcIPaddress	  SrcP	DIf	DstIPaddress	  DstP	P	 Fl	tos	Pkts	Octets	saa	  daa
#   2013-12-15 16:19:54.032	2013-12-15 16:19:54.262	0	  10.4.2.208     	60334	0	  210.55.204.219 	443	  6	 6	0	  2	   104	    1270	3400
#   2013-12-15 16:19:54.032	2013-12-15 16:19:54.262	0	  210.55.204.219 	443	  0	  10.4.2.208     	60334	6	 2	0	  1	   60	      12703400
#   2013-12-15 16:19:54.042	2013-12-15 16:19:54.174	0	  10.4.2.208     	60333	0	  210.55.204.219 	443	  6	 6	0	  2	   104	    1270	3400
#
# Destination file #{@ntm_dir}/wikk.2013-12-13_21:05:01.fdf.out
#
# logdatetime	sampleFreq	flowindex	firsttime(packet number)	flowkind	sourcepeertype	sourcetranstype	sourcepeeraddress	destpeeraddress	sourcetransaddressdesttransaddress	d_topdus	d_frompdus	d_tooctets	d_fromoctets	sourceadjacentaddress	destadjacentaddress
# 2013-12-13 21:00:15	10	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0
# 2013-12-13 21:00:15	10	6	0	3	1	6	10.4.2.208	210.55.204.219	60334	443	2 0 104	0	00-00-00-00-12-70	00-00-00-00-34-00
# 2013-12-13 21:00:15	10	2	0	3	1	6	210.55.204.219	10.4.2.208	443	60334	0 1	0 60	00-00-00-00-12-70	00-00-00-00-34-00
# 2013-12-13 21:00:15	10	6	0	3	1	6	10.4.2.208	210.55.204.219	60334	443	2	0	104	0 00-00-00-00-12-70	00-00-00-00-34-00
#                      *    * * *
#
```
