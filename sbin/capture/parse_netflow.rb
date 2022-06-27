#!/usr/local/bin/ruby
require 'getoptlong'
require 'time'
require 'pp'
require 'ipaddr'
RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/wikk_conf.rb"

VERSION = 1.2
CYCLE_FILE_HOURS = 1

#
# source file from  flow-cat ft-v05.2013-12-15.162002+1300 | flow-print -f 25
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
# Key difference is the sample times.
# Netflow stores:
#    start and end times to microseconds
#    You can get multiple records for the same stream, at the same time.
#    Interval is not uniform.
#    Hacked in last two bytes of source and destination adjacent addresses from data link layer into saa and daa fields.
# NeTraMet:
#    Only a start time in seconds
#    Interval time is fixed (10s), rather than different intervals
#    Single record for both in and out for this host in this interval.
#    Also records MAC addresses of source and destination (next router), so we can tell which path the packets took.

SAMPLEFREQ = 10
@base_time = nil # first time seen in input
@records = {} # store records in time order, as hashes of
FlowRecord = Struct.new(:logdatetime,	:sampleFreq, :flowindex,	:firsttime, :flowkind,	:sourcepeertype,	:sourcetranstype,	:sourcepeeraddress,	:destpeeraddress,	:sourcetransaddress,	:desttransaddress,	:d_topdus,	:d_frompdus,	:d_tooctets,	:d_fromoctets,	:sourceadjacentaddress,	:destadjacentaddress)

def insert_record(t, k1, k2, k3, k4, k5, v)
  if @records[t].nil? # t is a time stamp, and each timestamp can have multiple records.
    @records[t] = { k1 => { k2 => { k3 => { k4 => { k5 => v } } } } }
  elsif @records[t][k1].nil?
    @records[t][k1] = { k2 => { k3 => { k4 => { k5 => v } } } }
  elsif @records[t][k1][k2].nil?
    @records[t][k1][k2] = { k3 => { k4 => { k5 => v } } }
  elsif @records[t][k1][k2][k3].nil?
    @records[t][k1][k2][k3] = { k4 => { k5 => v } }
  elsif @records[t][k1][k2][k3][k4].nil?
    @records[t][k1][k2][k3][k4] = { k5 => v }
  elsif @records[t][k1][k2][k3][k4][k5].nil?
    @records[t][k1][k2][k3][k4][k5] = v
  else
    @records[t][k1][k2][k3][k4][k5][0] += v[0]
    @records[t][k1][k2][k3][k4][k5][1] += v[1]
    @records[t][k1][k2][k3][k4][k5][2] += v[2]
    @records[t][k1][k2][k3][k4][k5][3] += v[3]
  end
end

def each_record
  if @records != nil
    @records.sort.each do |t, vt| # t is time, vt is records for this time
      vt.each do |k1, vk1| # k1 is a source IP address, and vk1 is records of connections from this address.
        vk1.each do |k2, vk2| # k2 is source port number of the connections recorded by vk2
          vk2.each do |k3, vk3| # k3 is the destination IP address, and vk3 is the rest of the connection record
            vk3.each do |k4, vk4| # k4 is the destination port address, and vk4 is the rest of the connection record
              vk4.each do |k5, vk5| # k5 is the inet protocol number, and vk5 are the octet values, [d_topdus	d_frompdus	d_tooctets	d_fromoctets,  flow_number]
                yield(t, k1, k2, k3, k4, k5, vk5)
              end
            end
          end
        end
      end
    end
  end
end

# logdatetime	sampleFreq	flowindex	firsttime(packet number)	flowkind	sourcepeertype	sourcetranstype	sourcepeeraddress	destpeeraddress	sourcetransaddressdesttransaddress	d_topdus	d_frompdus	d_tooctets	d_fromoctets	sourceadjacentaddress	destadjacentaddress

def insert_flow_record(basetime, octets, flow)
  src_ip_addr = ip_address_to_subnet(flow[3])
  dest_ip_addr = ip_address_to_subnet(flow[6])
  # 0      1   2    3            4    5   6            7   8   9 10   11   12      13  14
  # Start End Sif	SrcIPaddress SrcP DIf DstIPaddress DstP P  Fl tos	Pkts Octets saa daa
  if direction(flow[3]) == 1 # incoming, then reverse src and dest and use d_frompdus and d_fromoctets
    insert_record(basetime, dest_ip_addr, flow[7], src_ip_addr, flow[4], flow[8], [ 0, 1, 0, octets, flow[9], flow[14], flow[13]]) # [d_topdus	d_frompdus	d_tooctets	d_fromoctets, flow_number, source_mac, dest_mac]
  else # outgoing then use d_topdus and d_tooctets
    insert_record(basetime, src_ip_addr, flow[4], dest_ip_addr, flow[7], flow[8], [ 1, 0, octets, 0, flow[9], flow[13], flow[14]]) # [d_topdus	d_frompdus	d_tooctets	d_fromoctets, flow_number, source_mac, dest_mac]
  end

  #   if(direction(flow[3]) == 1) #incoming, then reverse src and dest and use d_frompdus and d_fromoctets
  #     fr = FlowRecord.new(basetime.strftime("%Y-%m-%d %H:%M:%S"), SAMPLEFREQ, flow[9], 0, 3, 1, flow[8], dest_ip_addr, src_ip_addr, flow[7], flow[4], 0, 1,	0,	octets, mac_address(flow[14]), mac_address(flow[13]) )
  #   else #outgoing then use d_topdus and d_tooctets
  #     fr = FlowRecord.new(basetime.strftime("%Y-%m-%d %H:%M:%S"), SAMPLEFREQ, flow[9], 0, 3, 1, flow[8], src_ip_addr, dest_ip_addr, flow[4], flow[7], 1,	0,	octets,	0, mac_address(flow[13]), mac_address(flow[14]) )
  #   end
  #
  #   if @records[basetime] == nil
  #     #No entry for this time
  #     @records[basetime] = { [fr.sourcepeeraddress, fr.sourcetransaddress, fr.destpeeraddress, fr.desttransaddress, fr.sourcetranstype] => fr }
  #   elsif @records[basetime][[fr.sourcepeeraddress, fr.sourcetransaddress, fr.destpeeraddress, fr.desttransaddress, fr.sourcetranstype]] == nil
  #     #No record
  #     @records[basetime][[fr.sourcepeeraddress, fr.sourcetransaddress, fr.destpeeraddress, fr.desttransaddress, fr.sourcetranstype]] = fr
  #   else
  #     r = @records[basetime][[fr.sourcepeeraddress, fr.sourcetransaddress, fr.destpeeraddress, fr.desttransaddress, fr.sourcetranstype]]
  #     r.d_topdus += fr.d_topdus
  #     r.d_frompdus	+= fr.d_frompdus
  #     r.d_tooctets += fr.d_tooctets
  #     r.d_fromoctets += fr.d_fromoctets
  #     fr = nil #signal we don't need the struct anymore.
  #   end
end

# direction = 0 if src_ip is on our network
# direction = 1 if src_ip is not on our network.
def direction(src_ip)
  src = src_ip.split('.')
  return src[0] == '10' || (src[0] == '192' && src[1] == '168') || (src[0] == '100' && src[1] == '64') ? 0 : 1
end

def ip_address_to_subnet(ipaddr)
  # special case for tracking admin2 and admin1
  return DB_ADMIN_ORIG if ipaddr == DB_ADMIN_ORIG || ipaddr == DB_ADMIN # db/www on admin2
  return DSL_NET_ORIG if  ipaddr == GATE_DSL_ORIG  # gates DSL interface.
  return DSL_NET if  ipaddr == GATE_DSL  # gates DSL interface.

  ip_dot = ipaddr.split('.')
  if ip_dot[0] == '10' # Local home subnets have /27 mask, and we only want to record to the local subnet level.
    IPAddr.new(ipaddr + '/27').to_s
  elsif ip_dot[0] == '192' && ip_dot[1] == '168' # 192.168 addresses we only need to record to /24
    IPAddr.new(ipaddr + '/24').to_s
  elsif ip_dot[0] == '100' && ip_dot[1] == '64' # 100.64 addresses we only need to record to /27 # rubocop:disable Lint/DuplicateBranch
    IPAddr.new(ipaddr + '/27').to_s
  else # Other addresses just get passed through.
    ipaddr
  end
end

def mac_address(last_bytes)
  case last_bytes
  when '0EF8' then 'E0:46:9A:0B:0E:F8' # ADSL1
  when '1270' then 'E0:46:9A:0B:12:70' # ADSL2
  when '0B2C' then 'E0:46:9A:0B:0B:2C' # ADSL3
  when '97A4' then 'C4:3D:C7:BD:97:A4' # ADSL4
  when DSL5_SHORT_MAC then DSL5_MAC # ADLS5 VDSL1
  when DSL6_SHORT_MAC then DSL6_MAC # ADLS6 VDSL2
  when DSL7_SHORT_MAC then DSL7_MAC # ADLS7 VDSL3
  when GATE_SHORT_MAC then GATE_MAC # Admin1 ADSL net interface
  else; "00:00:00:00: #{last_bytes[0, 2]}:#{last_bytes[2, 2]}"
  end
end

def print_record(basetime, octets, flow)
  src_ip_addr = ip_address_to_subnet(flow[3])
  dest_ip_addr = ip_address_to_subnet(flow[6])
  # 0      1   2    3            4    5   6            7   8   9 10   11   12      13  14
  # Start End Sif	SrcIPaddress SrcP DIf DstIPaddress DstP P  Fl tos	Pkts Octets saa daa
  fr = if direction(flow[3]) == 1 # incoming, then reverse src and dest and use d_frompdus and d_fromoctets
         FlowRecord.new(basetime.strftime('%Y-%m-%d %H:%M:%S'), SAMPLEFREQ, flow[9], 0, 3, 1, flow[8], dest_ip_addr, src_ip_addr, flow[7], flow[4], 0, 1,	0,	octets, mac_address(flow[14]), mac_address(flow[13]) )
       else # outgoing then use d_topdus and d_tooctets
         FlowRecord.new(basetime.strftime('%Y-%m-%d %H:%M:%S'), SAMPLEFREQ, flow[9], 0, 3, 1, flow[8], src_ip_addr, dest_ip_addr, flow[4], flow[7], 1,	0,	octets,	0, mac_address(flow[13]), mac_address(flow[14]) )
       end
  fr.each { |v2| print "\t#{v2}" }
  print "\n"
end

# 0      1   2    3            4    5   6            7   8   9 10   11   12      13  14
# Start End Sif	SrcIPaddress SrcP DIf DstIPaddress DstP P  Fl tos	Pkts Octets saa daa
def add_record(fields)
  npackets = fields[11].to_i # From the Netflow packet
  noctets = fields[12].to_i  # From the Netflow packet
  basetime = Time.local(fields[0].year, fields[0].month, fields[0].mday, fields[0].hour, fields[0].min, (fields[0].sec / 10).to_i * 10) # First Interval we got a packet in.

  period = (fields[1] - basetime).to_f # Seconds between start and end times
  step_size = period / npackets # Step size may be in fractions of a second
  # puts step_size
  # puts period

  if period.abs > 600 # Should have records with no more than 5min flow time, so look for ones greater than 10 minutes just to be nice
    $stderr.puts 'Entry is longer than the 5minute recording window?'
    PP.pp fields, $stderr
    return
  end

  if step_size <= 0 # End date should be after start date.
    $stderr.puts 'Entry has end date < start date?'
    PP.pp fields, $stderr
    return
  end

  # return

  # Assume each packet is the same size (last packet may be short, if we have fraction)
  avg_pkt_size = (noctets / npackets).to_i # Octets/Packets  Integer Value
  last_pkt_size = avg_pkt_size + (noctets - (avg_pkt_size * npackets)) # To account for fractions we may have lost in last calculation.

  processed_packets = 0
  # Record packets, 1 packet per step.
  (0...period).step(step_size) do |f|
    processed_packets += 1
    index = (f / SAMPLEFREQ).to_i * SAMPLEFREQ
    if processed_packets == npackets # Last one.
      insert_flow_record(basetime + index, last_pkt_size, fields )
      # print_record(basetime + index, last_pkt_size, fields )
    else # Not last packet.
      insert_flow_record(basetime + index, avg_pkt_size, fields )
      # print_record(basetime + index, avg_pkt_size, fields )
    end
  end
end

def parse_line(line)
  fields = line.chomp.split("\t")
  fields.map!(&:strip)
  fields[0] = Time.parse(fields[0])
  fields[1] = Time.parse(fields[1])

  # Unexpected, but some of the logs get silly dates recorded.
  # So far, it always looks like the first date, but this may just be coincidental
  # Flow file headers also record start dates that can be after the entry!

  if @logfile_date != nil # Only do this if we have a reference timestamp from a file
    if fields[0] > @logfile_date      # startTime shouldn't be after logfile was last written to.
      fields[0] = @last_valid_date  # assign a date in range.
      if fields[1] > @logfile_date    # endTime shouldn't be after logfile was last written to.
        fields[1] = @last_valid_date + 1 # assume a 1 second period
      end
    elsif fields[1] > @logfile_date # start time was good, but end time beyond logfile timestamp
      fields[1] = @logfile_date # Set end date to mtime of the logfile
    end

    if fields[0] < @logfile_date - 600 # start time 10 min before the mtime of the log file (which is supposed to be 5min long)
      fields[0] = @logfile_date -  300 # Set start time to 5 minutes before the log file mtime, which is where we expect time to start.
    end

    if fields[1] < fields[0] # start date after end date
      fields[1] = fields[0] + 1  # Set endTime 1 second after startTime
    end

    if fields[0] == fields[1] # If packet sent within same millisecond, then get an error, so set end time to start + 1s
      fields[1] = fields[0] + 1
    end

    @last_valid_date = fields[0] if fields[0] > @last_valid_date # for the next loop
  end
  begin
    add_record(fields)
  rescue StandardError => e
    puts "add_record returned #{e}"
  end
end

# logdatetime	sampleFreq	flowindex	firsttime(packet number)	flowkind	sourcepeertype	sourcetranstype	sourcepeeraddress	destpeeraddress	sourcetransaddressdesttransaddress	d_topdus	d_frompdus	d_tooctets	d_fromoctets	sourceadjacentaddress	destadjacentaddress
# 2013-12-13 21:00:15	10	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0
# 2013-12-13 21:00:15	10	6	0	3	1	6	10.4.2.208	210.55.204.219	60334	443	2 0 104	0	00-00-00-00-12-70	00-00-00-00-34-00

def put_records
  # puts "#{(@base_time).strftime("%Y-%m-%d %H:%M:%s")}\t#{SAMPLEFREQ}\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0"
  records = @records.sort
  return if records.length == 0

  @base_time = records.first[0] - 10 # This is a null reference record for later processing
  # Because we are in time order, we can sequentially create log files at 4 hour intervals.
  t_current = Time.local(records.first[0].year, records.first[0].month, records.first[0].mday, (records.first[0].hour / CYCLE_FILE_HOURS).to_i * CYCLE_FILE_HOURS, 0, 0)
  t_next = t_current + (CYCLE_FILE_HOURS * 3600) # when we switch to the new file, it starts CYCLE_FILE_HOURS hours after current one.
  fd = init_file(t_current)

  begin
    each_record do |k, k1, k2, k3, k4, k5, v|
      # k = time, k1 = source_ip, k2 = source_port, k3 = dest_ip, k4 = dest_port, k5 = ip_protocol.
      # v = [d_topdus	d_frompdus	d_tooctets	d_fromoctets, flow_number, source_mac, dest_mac]
      if k >= t_next
        fd.close
        t_current = t_next
        t_next = t_current + (CYCLE_FILE_HOURS * 3600) # when we switch to the new file
        fd = init_file(t_current)
      end
      # logdatetime	sampleFreq	flowindex	firsttime(packet number)	flowkind	sourcepeertype	sourcetranstype	sourcepeeraddress	destpeeraddress	sourcetransaddressdesttransaddress	d_topdus	d_frompdus	d_tooctets	d_fromoctets	sourceadjacentaddress	destadjacentaddress
      fd.puts "#{k.strftime('%Y-%m-%d %H:%M:%S')}\t#{SAMPLEFREQ}\t#{v[4]}\t0\t3\t1\t#{k5}\t#{k1}\t#{k3}\t#{k2}\t#{k4}\t#{v[0]}\t#{v[1]}\t#{v[2]}\t#{v[3]}\t#{mac_address(v[5])}\t#{mac_address(v[6])}"
    end
  #       records.each do |k,r| #Array of hash's
  #         if(k >= t_next)
  #           fd.close
  #           t_current = t_next
  #           t_next = t_current + (CYCLE_FILE_HOURS * 3600) #when we switch to the new file
  #           fd = init_file(t_current)
  #         end
  #         if r != nil
  #           r.each do |k1,v1| #Hash's to each [src_host, src_port, dest_host, dest_port] tuple index to a FlowRecord Struct.
  #             if v1 != nil
  #               fd.puts v1.to_a.join("\t")
  #             end
  #           end
  #         end
  #       end
  rescue StandardError => e
    $stderr.puts 'put_records:' + e.to_s
  ensure
    fd.close if fd != nil
  end
end

def init_file(t)
  filename = "#{@ntm_dir}/wikk.#{t.strftime('%Y-%m-%d_%H:%M:%S')}.fdf.out"
  if File.exist?(filename)
    return File.open(filename, 'a')
  else
    @base_time = t - 10 # This is a null reference record for later processing
    fd = File.open(filename, 'a+')
    fd.puts "#logdatetime\tsampleFreq\tflowindex\tfirsttime\tflowkind\tsourcepeertype\tsourcetranstype\tsourcepeeraddress\tdestpeeraddress\tsourcetransaddress\tdesttransaddress\td_topdus\td_frompdus\td_tooctets\td_fromoctets\tsourceadjacentaddress\tdestadjacentaddress"
    fd.puts "#{@base_time.strftime('%Y-%m-%d %H:%M:%S')}\t#{SAMPLEFREQ}\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0"
    return fd
  end
end

def log_name_to_date_interval(filename)
  # Filenames of form ft-v05.2017-05-23.181501+1200
  begin
    date = filename.gsub(/^.*ft-v05\./, '')
    t = Time.strptime(date, '%Y-%m-%d.%H%M%S%Z')
    t -= t.sec
    firstdate = (t - t.min * 60) + t.min / FLOWLOG_INTERVAL * FLOWLOG_INTERVAL * 60
    mtime = t + FLOWLOG_INTERVAL * 60
    return mtime, firstdate
  rescue StandardError => e
    puts "log_name_to_date_interval(#{filename}): #{e}"
    return nil, nil
  end
end

# s = <<EOF
# Start	End	Sif	SrcIPaddress	SrcP	DIf	DstIPaddress	DstP	P	Fl	tos	Pkts	Octets	saa	daa
# 2014-01-03 19:55:00.000	2014-01-03 19:55:30.000	0	10.0.2.100     	55110	0	74.125.23.116  	80	6	0	0	21988	27262744	97A4	3400
# EOF
# @logfile_date = Time.parse("2014-01-03 20:00:00")
# @last_valid_date = @logfile_date - 300 #5 minutes before the last entry in the file.

@opts = [ # rubocop: disable Layout/SpaceInsideArrayLiteralBrackets # No idea why I get this
  [ '--version', '-V', GetoptLong::NO_ARGUMENT ],
  [ '--ntm_dir', '-n', GetoptLong::REQUIRED_ARGUMENT ]
]

@ntm_dir = NTM_LOG_DIR
opts = GetoptLong.new(*@opts)

begin
  opts.each do |opt, arg|
    case opt
    when '--version' then  print "Version #{VERSION}\n"
                           exit(0)
    when '--ntm_dir' then  @ntm_dir = arg
    end
  end
rescue GetoptLong::InvalidOption => e
  puts "#{e.message}"
end

if ARGV.length == 1
  @input_file_name = ARGV[0]
  @logfile_date, @last_valid_date = log_name_to_date_interval(@input_file_name)
  exit 0 if @logfile_date.nil?

  # Were using log mtime, but this can be wrong if the file has been restored from backup.
  # @logfile_date = File::stat(@input_file_name).mtime
  # @last_valid_date = @logfile_date - FLOWLOG_INTERVAL * 60  #5 minutes before the last entry in the file.
end

$stdin.each_line do |line|
  # s.each_line do |line|
  next unless line[0, 1] != '#'

  # fields = line.chomp.split("\t")
  # fields.each { |f| f = f.strip! }
  # puts fields.join(',')
  parse_line(line)
end

put_records
