#!/usr/local/bin/ruby
require 'getoptlong'
RLIB = '../../rlib'
require_relative "#{RLIB}/wikk_conf.rb"

VERSION = 1.2

@opts = [ # rubocop: disable Layout/SpaceInsideArrayLiteralBrackets # No idea why I get this
  [ '--version', '-V', GetoptLong::NO_ARGUMENT ],
  [ '--ntm_dir', '-n', GetoptLong::REQUIRED_ARGUMENT ]
]

@ntm_dir = ''
opts = GetoptLong.new(*@opts)

begin
  opts.each do |opt, arg|
    case opt
    when '--version' then  print "Version #{VERSION}\n"
                           exit(0)
    when '--ntm_dir' then  @ntm_dir = "--ntm_dir #{arg} "
    end
  end
rescue GetoptLong::InvalidOption => e
  puts "#{e.message}"
end

Dir.open(ARGV[0]).sort.each do |filename|
  Dir.chdir(ARGV[0])
  next unless filename =~ /^ft-v05.*/

  fs = File.stat(filename)
  next if fs.sticky?

  # puts "#{filename} NOT sticky"
  begin
    system "#{FLOW_PRINT} -f 25 < #{filename} | #{SBIN_DIR}/capture/parse_netflow.rb #{@ntm_dir} #{filename}"
    File.chmod(fs.mode + 0o1000, filename)
  rescue StandardError => e
    $stderr.puts e
  end
end
