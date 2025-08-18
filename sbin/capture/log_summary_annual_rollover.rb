#!/usr/local/bin/ruby
# Each year, we add in partitions for the next years logs
# And we remove the partitions in log_summary from 8 years ago.
# See manual add_partitions.sql example.
require 'wikk_sql'
require 'wikk_configuration'
load '/wikk/etc/wikk.conf' unless defined? WIKK_CONF

# Set up mysql connection
# Preload the partition table of log_summary.
def init
  @mysql_conf = WIKK::Configuration.new(MYSQL_CONF)

  partition_query = <<~SQL
    select partition_name from information_schema.partitions where table_name = 'log_summary';
  SQL
  @partitions = {}
  # Get the partiton table, so we can tell if we need to proceed
  WIKK::SQL.each_hash(@mysql_conf, partition_query) do |row|
    @partitions[row['partition_name']] = true
  end
end

# Checks to see if there is a partition for the year and month given.
# @param year [Integer] 4 digit year
# @param month [Integer] 1..12
# @return [Boolean]
def partition_present?(year:, month:)
  !@partitions["p#{year}_#{'%02d' % month}"].nil?
end

# In December, add in partitions for the next year
def add_monthly_log_summary_partions(year:)
  # We need to drop the catch all partition
  query1 = <<~SQL
    ALTER TABLE log_summary DROP PARTITION `p9999`
  SQL

  # Then we need to insert new monthly partitions
  # And add back the catchall at the end.
  partitions = Array.new(11) do |m|
    "PARTITION `p#{year}_#{'%02d' % (m + 1)}` VALUES LESS THAN ('#{year}-#{'%02d' % (m + 2)}-01')"
  end
  query2 = <<~SQL
    ALTER TABLE log_summary ADD PARTITION (
      #{partitions.join(',')} ,
      PARTITION  `p#{year}_12` VALUES LESS THAN ('#{year + 1}-01-01'),
      PARTITION  `p9999` VALUES LESS THAN (MAXVALUE)
    )
  SQL
  puts query1
  puts query2

  WIKK::SQL.connect(@mysql_conf) do |sql|
    sql.transaction do
      sql.query( query1 )
      sql.query( query2 )
    end
  end
end

# In December remove logs for year-8, Leaving just the December entries
# Thus we keep the last 7 years of logs (8 by the end of the new year)
def drop_old_log_summary_logs(year:)
  target_year = year - 8
  partitions =  [ "`p#{target_year - 1}_12`" ]
  (1..11).each do |m|
    partitions << "`p#{target_year}_#{'%02d' % m}`"
  end
  query = <<~SQL
    ALTER TABLE log_summary DROP PARTITION #{partitions.join(',')}
  SQL
  puts query

  WIKK::SQL.connect(@mysql_conf) do |sql|
    sql.query( query )
  end
end

t = Time.now
if t.month != 12
  warn 'Only run in December, and only once'
  # exit 1
end

init

# Double check we haven't already run this for next year
# Repeated calls, will cause the Transaction to fail, and need to unwind.
unless partition_present?(year: t.year + 1, month: 1)
  # add_monthly_log_summary_partions(year: t.year + 1)
end

# Check we haven't already deleted the old partitions.
# Though the worst case is, we fail because they have already gone.
if partition_present?(year: t.year - 7, month: 1)
  drop_old_log_summary_logs(year: t.year )
end
