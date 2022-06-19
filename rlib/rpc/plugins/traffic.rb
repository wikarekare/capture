#+---------------+------------+------+-----+---------+-------+
# | Field         | Type       | Null | Key | Default | Extra |
#+---------------+------------+------+-----+---------+-------+
# | bytes_in      | bigint(20) | YES  |     | NULL    |       |
# | bytes_out     | bigint(20) | YES  |     | NULL    |       |
# | hostname      | char(32)   | NO   | PRI |         |       |
# | log_timestamp | datetime   | NO   | PRI | NULL    |       |
#+---------------+------------+------+-----+---------+-------+

class Traffic < RPC
  def initialize(authenticated = false)
    super(authenticated)
    if authenticated
      @select_acl = [ 'hostname', 'log_timestamp' ]
      @set_acl = []
      @result_acl = [ 'hostname', 'log_timestamp', 'mbytes_in', 'mbytes_out' ]
    else
      @select_acl = []
      @set_acl = []
      @result_acl = []
    end
  end

  rmethod :create do |select_on: nil, set: nil, result: nil, **args|  # rubocop:disable Lint/UnusedBlockArgument"
    # new record
  end

  rmethod :last_traffic do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    # Pull data about customer
    where_string = to_where(select_on: select_on, acceptable_list: [ 'hostname' ])
    select_string = to_result(result: result, acceptable_list: @result_acl)
    order_by_string = 'order by log_timestamp desc limit 1'
    return sql_single_table_select(table: 'log_summary', select: select_string, where: where_string, order_by: order_by_string)
  end

  rmethod :read do |select_on: nil, set: nil, result: nil, order_by: nil, **_args|  # rubocop:disable Lint/UnusedBlockArgument"
    # Pull data about customer
    last_time = Time.parse(select_on['start_time'])
    end_time = Time.parse(select_on['end_time'])
    time_diff = end_time - last_time

    if time_diff <= 14400 # 4 hours, in seconds
      step_size = 10 # traffic is recorded every 10 seconds, for 4 hours gives 1440 points
      time_format_str = '%Y-%m-%d %H:%i:%s'  # recover in 10s intervals of the logs
    elsif time_diff <= 86400 # 1 day, in seconds
      step_size = 60 # 1 minute intervals. for a day gives 1440 points.
      time_format_str = '%Y-%m-%d %H:%i:00'  # recover in 1m intervals of the logs
    elsif time_diff <= (31 * 86400) # 1 months. 31 days, in seconds
      step_size = 3600 # 1 hour intervals, for 31 days gives 744 points
      time_format_str = '%Y-%m-%d %H:00:00'  # recover in 1 hour intervals of the logs
    else
      step_size = 86400 # 1 day intervals, for a year, gives 365 points.
      time_format_str = '%Y-%m-01 00:00:00'  # recover in 1 month intervals of the logs
    end

    query = <<~SQL
      SELECT  date_format(log_timestamp, "#{time_format_str}") as event_time, sum(bytes_in/(1024*1024.0)) as mbytes_in, sum((bytes_out)/(1024*1024.0)) as mbytes_out
      FROM    log_summary
      WHERE   hostname = '#{WIKK::SQL.escape(select_on['hostname'])}'         AND
              log_timestamp >= '#{last_time.strftime('%Y-%m-%d %H:%M:%S')}' AND
              log_timestamp <= '#{end_time.strftime('%Y-%m-%d %H:%M:%S')}'
      GROUP BY event_time
      ORDER BY event_time;
    SQL

    rows = []
    WIKK::SQL.connect(@config) do |sql|
      sql.each_hash(query) do |row|
        log_timestamp = Time.parse(row['event_time'])
        # Filling in missing points with nil values, helps with graphing.
        time_range(start_time: last_time, end_time: log_timestamp, step: step_size) do |t|
          rows << { 'log_timestamp' => t.strftime('%Y-%m-%d %H:%M:%S'), 'mbytes_in' => nil, 'mbytes_out' => nil }
        end
        rows << { 'log_timestamp' => row['event_time'], 'mbytes_in' => row['mbytes_in'].to_f, 'mbytes_out' => row['mbytes_out'].to_f }
        last_time = log_timestamp + step_size
      end

      # Add nil entries, from the last record, until the end time. This helps with graphing, so we can mark these points as missing.
      time_range(start_time: last_time, end_time: end_time, step: step_size) do |t|
        rows << { 'log_timestamp' => t.strftime('%Y-%m-%d %H:%M:%S'), 'mbytes_in' => nil, 'mbytes_out' => nil }
      end

      # Got data, so return it.
      return  { 'rows' => rows, 'affected_rows' => sql.affected_rows, 'hostname' => select_on['hostname'] }
    end

    # failed to get data, so return no rows.
    # Add nil entries, for all records This helps with graphing, so we can mark these points as missing from the log.
    time_range(start_time: last_time, end_time: Time.parse(select_on['end_time']), step: step_size) do |t|
      rows << { 'log_timestamp' => t.strftime('%Y-%m-%d %H:%M:%S'), 'mbytes_in' => nil, 'mbytes_out' => nil }
    end

    return { 'rows' => rows, 'affected_rows' => sql.affected_rows, 'hostname' => select_on['hostname'] }
  end

  rmethod :update do |select_on: nil, set: nil, result: nil, **args|  # rubocop:disable Lint/UnusedBlockArgument"
    # We don't actually do this.
  end

  rmethod :delete do |select_on: nil, set: nil, result: nil, **args|  # rubocop:disable Lint/UnusedBlockArgument"
    # We don't actually do this.
  end
end
