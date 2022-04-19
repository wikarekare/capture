#!/usr/local/ruby3.0/bin/ruby
require 'time' #don't we all
require 'pp'
require 'yaml'
require 'mysql'
require 'wikk_configuration'
RLIB='/wikk/rlib'
require_relative "#{RLIB}/wikk_conf.rb"  

def adsl_ip(ip)
  external1 = "121.99.232.233"
  external2 = "121.99.233.235"
  external3 = "121.99.232.199"
  external4 = "121.99.233.37"
  external5 = EXTERNAL5
  external6 = EXTERNAL6
  external7 = EXTERNAL7 
  if ip == external7 || ip == external5 || ip == external6 || ip == external1 || ip == external2 || ip == external3 || ip == external4
    return true
  else
    return false
  end
end

#test data
s = <<EOF
#logdatetime	sampleFreq	flowindex	firsttime	flowkind	sourcepeertype	sourcetranstype	sourcepeeraddress	destpeeraddress	sourcetransaddress	desttransaddress	d_topdus	d_frompdus	d_tooctets	d_fromoctets	sourceadjacentaddress	destadjacentaddress
2014-01-06 07:59:50	10	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0
2014-01-06 08:00:00	10	3	0	3	1	6	10.4.2.32	178.255.83.1	52134	80	7	6	611	1178	00:00:F8:1A:34:00	E0:46:9A:0B:0B:2C
2014-01-06 09:17:30	10	3	0	3	1	6	10.1.3.128	204.77.28.34	50926	80	1	1	186	215	00:00:F8:1A:34:00	C4:3D:C7:BD:97:A4
2014-01-06 09:17:30	10	3	0	3	1	6	10.1.3.128	204.77.28.34	50927	80	1	1	200	215	00:00:F8:1A:34:00	C4:3D:C7:BD:97:A4
2014-01-06 09:17:30	10	7	0	3	1	6	10.1.3.128	23.43.145.76	50928	443	1	2	250	2368	00:00:F8:1A:34:00	C4:3D:C7:BD:97:A4
2014-01-06 09:17:30	10	0	0	3	1	6	10.1.3.140	74.125.235.213	50824	443	1	1	147	165	00:00:F8:1A:34:00	C4:3D:C7:BD:97:A4
2014-01-06 09:17:30	10	0	0	3	1	17	10.1.3.128	157.56.52.43	17041	40002	1	1	139	49	00:00:F8:1A:34:00	C4:3D:C7:BD:97:A4
EOF

@records = {}

def line_ctl_from_yaml
  File.open(CUSTOMER_NETWORKS, 'r') { |fd| @networks = YAML.load(fd) }
end

def insert_record(r)
  src_ip = r[7].split('.')
  dest_ip = r[8].split('.')
  return if r[7] == "0" || #Hmmm
           adsl_ip(r[8]) ||
           dest_ip[0] == '10' ||  #Destination is local customer net
           ( dest_ip[0] == '169' && dest_ip[1] == '254' )   || #Destination is Failed DHCP address
           ( dest_ip[0] == '192' && dest_ip[1] == '168' )   || #Destination is local link
           ( dest_ip[0] == '100' && dest_ip[1] == '64' )   ||  #Destination is local link
           ( dest_ip[0] == '172' && dest_ip[1].to_i >= 16 && dest_ip[1].to_i < 32 )   || #Destination is 172.16.0.0/12
           ( r[7] == '255.255.255.255' ) || #Broadcast
           ( dest_ip[0].to_i >= 224 && dest_ip[0].to_i <= 239 ) || #Destination is multicast
           ( src_ip[0].to_i >= 224 && src_ip[0].to_i <= 239 ) || #Source is multicast
           ( src_ip[0] == "169" && src_ip[1] == "254"  ) || #Source is Failed DHCP Address
           ( src_ip[0] == "192" && src_ip[1] == "168" && src_ip[2] != "249" ) #|| #Source is local link address
           #( r[7] != GATE_DSL2 && r[7] != DSL5 && r[7] != DSL6 && r[7] != DSL7 )
           
  dt = Time.parse(r[0])
  if @records[dt] == nil
    @records[dt] = { r[7] => [r[13].to_i, r[14].to_i] }
  elsif @records[dt][r[7]] == nil
    @records[dt][r[7]] = [r[13].to_i, r[14].to_i]
  else
    @records[dt][r[7]][0] += r[13].to_i
    @records[dt][r[7]][1] += r[14].to_i
  end  
end

def hostname(ip)
  case ip
  when DSL1 ; return 'link1'
  when DSL2 ; return 'link2'
  when DSL3 ; return 'link3'
  when DSL4 ; return 'link4'
  when DSL5 ; return 'link5'
  when DSL6 ; return 'link6'
  when DSL7 ; return 'link7'
  when '10.0.1.103' ; return 'admin1'
  when '10.0.1.102' ; return 'admin2'
  when '100.64.0.4'; return 'db'
  when '100.64.0.1'; return 'gate'
  else
    host = @networks[ip]
    return ip if host == nil
    return host
  end
end

def each_record
  @records.sort.each do |rk,rv|
    rv.each do |hk, hv|
      yield(rk, hostname(hk), hv)
    end
  end
end

def insert_link_record(r)
  if r[15] == DSL1_MAC || r[16] == DSL1_MAC     #ADSL1
    r[7] = DSL1
  elsif r[15] == DSL2_MAC || r[16] == DSL2_MAC  #ADSL2
    r[7] = DSL2
  elsif r[15] == DSL3_MAC || r[16] == DSL3_MAC  #ADSL3
    r[7] = DSL3
  elsif r[15] == DSL4_MAC || r[16] == DSL4_MAC #ADSL4
    r[7] = DSL4
  elsif r[15] == DSL5_MAC || r[16] == DSL5_MAC  #ADSL5 VDSL1
    r[7] = DSL5
  elsif r[15] == DSL6_MAC || r[16] == DSL6_MAC  #ADSL6 VDSL2
    r[7] = DSL6
  elsif r[15] == DSL7_MAC || r[16] == DSL7_MAC  #ADSL7 VDSL3
    r[7] = DSL7
  else
    return
  end
  insert_record(r)
end

def save
  @mysql_conf = WIKK::Configuration.new(MYSQL_CONF)
  my = Mysql::new(@mysql_conf.host, @mysql_conf.dbuser, @mysql_conf.key, @mysql_conf.db)
  begin
    each_record do |dt, host, sum|
      my.query( "replace into log_summary (  bytes_in, bytes_out, hostname, log_timestamp ) " +
                " values ( #{sum[1]}, #{sum[0]}, '#{host}' ,'#{dt.strftime("%Y-%m-%d %H:%M:%S")}' )"  )
    end
  ensure
    my.close if my != nil
  end
end

#Parse each file in the argument line
#Or from test data s.each_line do |l|
ARGF.each_line do |l|
	tokens = l.chomp.split("\t")
	if(tokens[0][0,1] != '#')
  	insert_record(tokens)
    insert_link_record(tokens)
  end
end

line_ctl_from_yaml

save

=begin
#Test dump
each_record do |date, host, sum_in, sum_out|
  puts "#{date} #{host} #{sum_in} #{sum_out}"
end
=end
	
	
