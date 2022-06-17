#!/usr/local/bin/ruby
def object_clean_dir(directory:)
  begin
    Dir.open(directory).each do |filename|
      next unless filename =~ /^wikk.*_10.summary/

      base_file = filename.gsub(/_10.summary/, '')
      qualified_filename = directory + '/' + base_file
      begin
        summary_file = qualified_filename + '.summary'
        summary_10_filename = qualified_filename + '_10.summary'
        puts "rm -f #{qualified_filename}\t#{summary_file}\t#{summary_10_filename}"
        `/bin/rm -f #{qualified_filename} #{summary_file} #{summary_10_filename}`
      rescue StandardError => e
        puts "rm -f #{qualified_filename} failed with error: #{e}"
      end
    end
  rescue StandardError => e
    puts "object_clean_dir(#{directory}) : #{e}"
  end
end

object_clean_dir(directory: '/wikk/var/tmp/ntm')
