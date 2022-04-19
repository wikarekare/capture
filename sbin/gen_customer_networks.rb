#!/usr/local/ruby3.0/bin/ruby

# Generate the IP to site name yml file we use for processing
# traffic logs into site usage data.

require 'wikk_sql'
require 'wikk_configuration'

load '/wikk/etc/wikk.conf'

SITE_IP_QUERY = 'select INET_NTOA(dns_network.network + (dns_subnet.subnet * dns_network.subnet_size) + host_index) as ip, customer.site_name as site_name  from dns_subnet, dns_network, dns_host, customer, customer_dns_subnet where  customer.customer_id = customer_dns_subnet.customer_id and customer_dns_subnet.dns_subnet_id = dns_subnet.dns_subnet_id and dns_subnet.dns_subnet_id = dns_host.dns_subnet_id and dns_subnet.dns_network_id = dns_network.dns_network_id  and dns_host.host_index = 0 order by site_name'

# Write IP address, site_name pairs to YML file
def dump_customer_networks
  File.open(CUSTOMER_NETWORKS, 'w+', 0o644) do |fd|
    fd.puts '---'
    @site_ip.each do |ip, site|
      fd.puts "#{ip}: #{site}"
    end
  end
end

# Read the IP address, site_name pairs from the DB.
def load_site_ips
  @site_ip = {}
  @mysql_conf = WIKK::Configuration.new(MYSQL_CONF)
  WIKK::SQL.connect(@mysql_conf) do |sql|
    sql.each_hash(SITE_IP_QUERY) do |row|
      @site_ip[row['ip']] = row['site_name']
    end
  end
end

load_site_ips
dump_customer_networks if @site_ip.length > 1
