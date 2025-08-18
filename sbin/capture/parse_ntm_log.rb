#!/usr/local/bin/ruby
require 'time' # don't we all
require 'pp'
require 'yaml'
require 'wikk_sql'
require 'wikk_configuration'

load '/wikk/etc/wikk.conf' unless defined? WIKK_CONF

def adsl_ip(ip)
  external1 = '121.99.232.233'
  external2 = '121.99.233.235'
  external3 = '121.99.232.199'
  external4 = '121.99.233.37'
  external5 = EXTERNAL5
  external6 = EXTERNAL6
  external7 = EXTERNAL7
  if ip == external7 || ip == external5 || ip == external6 || ip == external1 || ip == external2 || ip == external3 || ip == external4
    return true
  else
    return false
  end
end

@records = {}

def line_ctl_from_yaml
  File.open(CUSTOMER_NETWORKS, 'r') { |fd| @networks = YAML.load(fd) } # rubocop:disable Security/YAMLLoad
end

def insert_record(r)
  src_ip = r[7].split('.')
  dest_ip = r[8].split('.')
  return if r[7] == '0' || # Hmmm
            adsl_ip(r[8]) ||
            dest_ip[0] == '10' ||  # Destination is local customer net
            ( dest_ip[0] == '169' && dest_ip[1] == '254' )   || # Destination is Failed DHCP address
            ( dest_ip[0] == '192' && dest_ip[1] == '168' )   || # Destination is local link
            ( dest_ip[0] == '100' && dest_ip[1] == '64' ) || # Destination is local link
            ( dest_ip[0] == '172' && dest_ip[1].to_i.between(16, 31) ) || # Destination is 172.16.0.0/12
            ( r[7] == '255.255.255.255' ) || # Broadcast
            dest_ip[0].to_i.between(224, 239) || # Destination is multicast
            src_ip[0].to_i.between(224, 239) || # Source is multicast
            ( src_ip[0] == '169' && src_ip[1] == '254' ) || # Source is Failed DHCP Address
            ( src_ip[0] == '192' && src_ip[1] == '168' && src_ip[2] != '249' ) # || #Source is local link address

  # ( r[7] != GATE_DSL2 && r[7] != DSL5 && r[7] != DSL6 && r[7] != DSL7 )

  dt = Time.parse(r[0])
  if @records[dt].nil?
    @records[dt] = { r[7] => [ r[13].to_i, r[14].to_i ] }
  elsif @records[dt][r[7]].nil?
    @records[dt][r[7]] = [ r[13].to_i, r[14].to_i ]
  else
    @records[dt][r[7]][0] += r[13].to_i
    @records[dt][r[7]][1] += r[14].to_i
  end
end

def hostname(ip)
  case ip
  when DSL1 then return 'link1'
  when DSL2 then return 'link2'
  when DSL3 then return 'link3'
  when DSL4 then return 'link4'
  when DSL5 then return 'link5'
  when DSL6 then return 'link6'
  when DSL7 then return 'link7'
  when '10.0.1.103' then return 'admin1'
  when '10.0.1.102' then return 'admin2'
  when '100.64.0.4' then return 'db'
  when '100.64.0.1' then return 'gate'
  else
    host = @networks[ip]
    return ip if host.nil?

    return host
  end
end

def each_record
  @records.sort.each do |rk, rv|
    rv.each do |hk, hv|
      yield(rk, hostname(hk), hv)
    end
  end
end

def insert_link_record(r)
  if r[15] == DSL1_MAC || r[16] == DSL1_MAC     # ADSL1
    r[7] = DSL1
  elsif r[15] == DSL2_MAC || r[16] == DSL2_MAC  # ADSL2
    r[7] = DSL2
  elsif r[15] == DSL3_MAC || r[16] == DSL3_MAC  # ADSL3
    r[7] = DSL3
  elsif r[15] == DSL4_MAC || r[16] == DSL4_MAC # ADSL4
    r[7] = DSL4
  elsif r[15] == DSL5_MAC || r[16] == DSL5_MAC  # ADSL5 VDSL1
    r[7] = DSL5
  elsif r[15] == DSL6_MAC || r[16] == DSL6_MAC  # ADSL6 VDSL2
    r[7] = DSL6
  elsif r[15] == DSL7_MAC || r[16] == DSL7_MAC  # ADSL7 VDSL3
    r[7] = DSL7
  else
    return
  end
  insert_record(r)
end

def save
  @mysql_conf = WIKK::Configuration.new(MYSQL_CONF)
  WIKK::SQL.connect(@mysql_conf) do |sql|
    each_record do |dt, host, sum|
      query = <<~SQL
        REPLACE INTO log_summary (  bytes_in, bytes_out, hostname, log_timestamp )
          VALUES ( #{sum[1]}, #{sum[0]}, '#{host}' ,'#{dt.strftime('%Y-%m-%d %H:%M:%S')}' )
      SQL
      sql.query( query )
    end
  end
end

# Parse each file in the argument line
# Or from test data s.each_line do |l|
ARGF.each_line do |l|
  tokens = l.chomp.split("\t")
  if tokens[0][0, 1] != '#'
    insert_record(tokens)
    insert_link_record(tokens)
  end
end

line_ctl_from_yaml

save
