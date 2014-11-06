#!/usr/bin/env ruby
require "./volcano_ftp.rb"

def start(port)
  begin
    ftp = VolcanoFtp.new(port)
    ftp.run
  rescue SystemExit, Interrupt
    puts "Caught CTRL+C, exiting"
  rescue RuntimeError => e
    puts e
  end
end

case ARGV[1]
when "start"
  start(ARGV[0])
when "stop"
  puts "Not implemented yet"
when "restart"
  puts "Not implemented yet"
else
  puts "Woot ?!"
end
