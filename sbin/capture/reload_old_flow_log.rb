#!/usr/local/bin/ruby

unless defined? WIKK_CONF
  load '/wikk/etc/wikk.conf'
end

DAYS_IN_MONTH = [ nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ]

def days_in_month(year, month)
  return 29 if month == 2 && Date.gregorian_leap?(year)

  DAYS_IN_MONTH[month]
end

def reload_flow_log(year:, month:, day:)
  target_dir = "#{year}/#{year}-#{'%02d' % month}/#{year}-#{'%02d' % month}-#{'%02d' % day}"
  puts "Updating dir: #{target_dir}"
  system("#{SBIN_DIR}/capture/isnewer_flow.rb --ntm_dir #{TMP_DIR}/ntm #{FLOW_LOG_DIR}/log/#{target_dir}")
end

year = 2015
(7..12).each do |m|
  (1..days_in_month(year, m)).each do |d|
    reload_flow_log(year: year, month: m, day: d)
  end
end

reload_flow_log(year: 2016, month: 1, day: 1)
