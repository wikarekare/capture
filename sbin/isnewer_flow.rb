#!/usr/local/ruby3.0/bin/ruby
require 'getoptlong' 
RLIB='../../rlib'
require_relative "#{RLIB}/wikk_conf.rb"  

VERSION=1.2

@opts = [
        ["--version", "-V", GetoptLong::NO_ARGUMENT ],
        ["--ntm_dir", "-n", GetoptLong::REQUIRED_ARGUMENT]
]

@ntm_dir = ''
opts = GetoptLong.new(*@opts)

begin
  opts.each do |opt, arg|
    case opt
    when '--version' then  print "Version #{VERSION}\n"; exit(0)
    when '--ntm_dir' then  @ntm_dir = "--ntm_dir #{arg} "
    end
  end
rescue GetoptLong::InvalidOption => error
  puts "#{error.message}"
end 


Dir.open(ARGV[0]).sort.each do |filename|
  Dir.chdir(ARGV[0])
  if filename =~ /^ft-v05.*/
    fs = File.stat(filename)
    if !fs.sticky?
      #puts "#{filename} NOT sticky"
      begin
        system  "#{FLOW_PRINT} -f 25 < #{filename} | #{SBIN_DIR}/capture/parse_netflow.rb #{@ntm_dir} #{filename}"
        File.chmod(fs.mode + 01000, filename)
      rescue Exception=>error
        STDERR.puts error
      end
    else
     # puts "#{filename} sticky" #Nothing to do
    end
  end
end

