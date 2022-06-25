RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/account/graph_sql_traffic.rb"
require_relative 'ping_log.rb'
require_relative 'signal_log_new.rb'

# Magic host name 'all'
def gen_images(mysql_conf:, hosts:, graph_types:, start_time:, end_time:)
  images = []
  message = []

  hosts.each do |h|
    h = 'all' if h == '' || h.nil? # Unspecified hostname == 'all'
    h = h.gsub(/external/, 'link') if h =~ /^external/
    graph_types.each do |gt|
      begin
        case gt
        when 'usage'; # Line graph of usage over the period
          images << if h == '' || h == 'all'
                      Graph_Total_Usage.new(mysql_conf, nil, Time.at(start_time), Time.at(end_time)).images
                    else
                      Graph_Host_Usage.new(mysql_conf, h, Time.at(start_time), Time.at(end_time)).images
                    end
        when 'graph3d'; # 3D impulse graph of the usage of the period
          images << if h == 'all' || h == 'dist'
                      Graph_3D.new(mysql_conf, h, false, Time.at(start_time), Time.at(end_time) ).images
                    else
                      Graph_3D.graph_parent(mysql_conf, h, false, Time.at(start_time), Time.at(end_time) ).images
                    end
        when 'hosts'; # Bubble graph of hosts connected to (bit unreadable, if there are lots). Data from ntm
          images << if h =~ /wikk[0-9][0-9][0-9]/
                      Graph_Connections.new(h + '-net', Time.at(start_time), Time.at(end_time)).images
                    else
                      Graph_Connections.new(h, Time.at(start_time), Time.at(end_time)).images
                    end
        when 'host_histogram'; # Histogram of hosts (better readablity, if lots). Data from flow logs
          images << if h =~ /wikk[0-9][0-9][0-9]/
                      Graph_flow_Host_Hist_trim.new(h + '-net', Time.at(start_time), Time.at(end_time)).images
                    else
                      Graph_flow_Host_Hist_trim.new(h, Time.at(start_time), Time.at(end_time)).images
                    end
        when 'ports'; # Bubbles of ports used. Data from ntm
          images << if h =~ /wikk[0-9][0-9][0-9]/
                      Graph_Ports.new(h + '-net', Time.at(start_time), Time.at(end_time)).images
                    else
                      Graph_Ports.new(h, Time.at(start_time), Time.at(end_time)).images
                    end
        when 'port_histogram'; # Port histogram (better readability than bubble version). Data from flow logs
          images << if h =~ /wikk[0-9][0-9][0-9]/
                      Graph_Flow_Ports_Hist_trim.new(h + '-net', Time.at(start_time), Time.at(end_time)).images
                    else
                      Graph_Flow_Ports_Hist_trim.new(h, Time.at(start_time), Time.at(end_time)).images
                    end
        when 'signal'; # 2D graph. Signal level over the period
          signal_record = Signal_Class.new(mysql_conf)
          if (error = signal_record.gnuplot(h, Time.at(start_time), Time.at(end_time)) ).nil?
            images << "<p><img src=\"/netstat/#{h}-signal.png\"></p>\n"
          else
            message << error.to_s
          end
        when 'traffic_split'; # In and out in separate, side by side, graphs
          images << if h == 'all' || h == 'dist'
                      Graph_2D.graph_border(mysql_conf, true, Time.at(start_time), Time.at(end_time) )
                    else
                      Graph_2D.new(mysql_conf, h, true, Time.at(start_time), Time.at(end_time) ).images
                    end
        when 'traffic_dual'; # In and out in stacked, single graph
          images << if h == 'all' || h == 'dist'
                      Graph_2D.graph_border(mysql_conf, false, Time.at(start_time), Time.at(end_time) )
                    else
                      Graph_2D.new(mysql_conf, h, false, Time.at(start_time), Time.at(end_time) ).images
                    end
        when 'ping'; # Smoke Ping like graph, over period.
          h = h.gsub(/link/, 'external') if h =~ /^link/ # Make up your mind!
          ping_record = Ping_Log.new(mysql_conf)
          if (error = ping_record.gnuplot(h, Time.at(start_time), Time.at(end_time)) ).nil?
            images << "<p><img src=\"/netstat/#{h}-p5f.png?start_time=#{Time.at(start_time).xmlschema}&end_time=#{Time.at(end_time).xmlschema}\"></p>\n"
          else
            message << error.to_s
          end
        when 'graphP2'; # Port histogram. Data from ntm
          images += if h =~ /wikk[0-9][0-9][0-9]/
                      Graph_Ports_Hist.new(h + '-net', Time.at(start_time), Time.at(end_time)).images
                    else
                      Graph_Ports_Hist.new(h, Time.at(start_time), Time.at(end_time)).images
                    end
        when 'graphC2'; # Host Histogram. Data from ntm
          images << if h =~ /wikk[0-9][0-9][0-9]/
                      Graph_Host_Hist.new(h + '-net', Time.at(start_time), Time.at(end_time)).images
                    else
                      Graph_Host_Hist.new(h, Time.at(start_time), Time.at(end_time)).images
                    end
        when 'dist'; # 2D distribution site traffic, plus each client.
          if h =~ /^link/
            images << Graph_2D.new(mysql_conf, h, false, Time.at(start_time), Time.at(end_time)).images
            images << Graph_2D.graph_link(mysql_conf, h, false, Time.at(start_time), Time.at(end_time) )
          elsif h == 'dist' || h == 'all'
            images << Graph_2D.graph_all(mysql_conf, false, Time.at(start_time), Time.at(end_time) )
          else
            images << Graph_2D.new(mysql_conf, h, false, Time.at(start_time), Time.at(end_time)).images
            images << Graph_2D.graph_clients(mysql_conf, h, false, Time.at(start_time), Time.at(end_time) )
          end
        when 'pdist'; # 2D distribution site pings, plus each client.
          images << Graph_2D.new(mysql_conf, h, false, Time.at(start_time), Time.at(end_time)).images
          ping_record = Ping_Log.new(mysql_conf)
          if (error = ping_record.gnuplot(h, Time.at(start_time), Time.at(end_time)) ).nil?
            images << "<p><img src=\"/netstat/#{h}-p5f.png?start_time=#{Time.at(start_time).xmlschema}&end_time=#{Time.at(end_time).xmlschema}\"></p>\n"
          else
            message << error.to_s
          end
          images << Ping_Log.graph_clients(mysql_conf, h, Time.at(start_time), Time.at(end_time) )
        when 'internal_hosts'; # Histogram of a sites internal IP address usage.
          images << Graph_Internal_Hosts.new( h, Time.at(start_time), Time.at(end_time)).images
        else # 2D traffic. Assumes traffic graphs split in/out
          images << if h == 'all'
                      Graph_2D.graph_border(mysql_conf, false, Time.at(start_time), Time.at(end_time) )
                    else
                      Graph_2D.new(mysql_conf, h, false, Time.at(start_time), Time.at(end_time) ).images
                    end
        end
      rescue Exception => e # rubocop:disable Lint/RescueException Called by CGI, so we want it to report back
        backtrace = e.backtrace[0].split(':')
        message << "MSG: (#{File.basename(backtrace[-3])} #{backtrace[-2]}): #{e.message.to_s.gsub(/'/, '\\\'')}"
      end
    end
  end
  message.collect! { |m| m.gsub(/\n/, '').gsub(/"/, '\"').gsub(/</, '&lt;').gsub(/>/, '&gt;') }
  images.collect! { |im| im.gsub(/\n/, '').gsub(/"/, '\"') }
  return images, message
end
