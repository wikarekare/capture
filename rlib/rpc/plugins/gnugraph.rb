require "#{RLIB}/monitor/gen_images.rb"
# Legacy. We are moving all this to run in the browser.
# Not an SQL plugin.
# Generates graphs on the web site, and returns URIs to them.
class GnuGraph < RPC
  # Expect "hosts": ["host1",...]
  def initialize(authenticated = false)
    super(authenticated)
    @authenticated = authenticated
    @select_acl = [ 'hosts', 'start_time', 'end_time', 'last_seen' ]
    @result_acl = [ 'traffic_split', 'ping', 'graph3d', 'traffic_dual' ]
    @set_acl = []
    @requestor = ENV.fetch('REMOTE_ADDR')
    @local_site = site_name(@requestor, '255.255.255.224')
    if authenticated
      @result_acl += [ 'usage', 'hosts', 'host_histogram', 'ports', 'port_histogram', 'signal',
                       'internal_hosts', 'dist', 'graphP2', 'graphC2', 'pdist'
                     ]
    end
  end

  rmethod :graph do |select_on: nil, set: nil, result: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    if !@authenticated
      raise 'Not Local' if @local_site == ''

      if select_on['hosts'].length == 1 && select_on['hosts'][0] == @local_site
        @result_acl += [ 'usage', 'host_histogram', 'port_histogram', 'internal_hosts' ]
      end
    end

    select_on.each { |k, _v| acceptable(field: k, acceptable_list: @select_acl) } if select_on != nil
    result.each { |k, _v| acceptable(field: k, acceptable_list: @result_acl) } if result != nil

    raise 'Hostname(s) required' if select_on['hosts'].nil? || select_on['hosts'].length == 0

    hosts = select_on['hosts'].instance_of?(Array) ? select_on['hosts'] : [ select_on['hosts']]

    start_time = if select_on['start_time'].nil? || select_on['start_time'].length == 0
                   Time.now.to_i - 3600 # Default to 1 hour
                 else
                   Time.parse(select_on['start_time']).to_i
                 end

    end_time = if select_on['end_time'].nil? || select_on['end_time'].length == 0
                 start_time + 3600 # Default to one hour
               else
                 Time.parse(select_on['end_time']).to_i
               end

    raise 'End time < Start time, or interval is 0' if end_time < start_time || end_time == start_time

    graph_types = result.length == 0 ? [ 'traffic_split', 'ping' ] : result

    images, message = gen_images(mysql_conf: @db_config, hosts: hosts, graph_types: graph_types,
                                 start_time: start_time, end_time:  end_time
    )

    message.collect! { |s| s.gsub(/\n/, ' ') }
    time_diff = end_time - start_time
    days = (time_diff / 86400).to_i
    hours = ((time_diff - days * 86400) / 3600.0).round(2)
    encoded = { 'start_time' => Time.at(start_time).to_sql,
                'end_time' => Time.at(end_time).to_sql,
                'days' => days,
                'hours' => hours,
                'hosts' => hosts,
                'graph_type' => graph_types,
                'images' => images,
                'messages' => message
           }
    return encoded
  end

  private def site_name(address, mask)
    query = <<~SQL
      SELECT customer.site_name
      FROM customer,dns_network,dns_subnet,customer_dns_subnet
      WHERE customer.customer_id = customer_dns_subnet.customer_id
      AND customer_dns_subnet.dns_subnet_id = dns_subnet.dns_subnet_id
      AND dns_subnet.dns_network_id = dns_network.dns_network_id
      AND (dns_network.network+subnet * subnet_size) = (INET_ATON('#{address}') & INET_ATON('#{mask}'))
    SQL
    WIKK::SQL.connect(@db_config) do |sql|
      result = sql.query_hash(query)
      return result.length > 0 ? result.first['site_name'] : ''
    end
  end
end
