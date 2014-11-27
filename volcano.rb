#!/usr/bin/env ruby
require "./volcano_ftp.rb"
require 'daemons'
require 'optparse'

config = {
  :port => 9999
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} start [--port PORT_NUMBER]"

  opts.on("--port PORT", "Port Number") do |port|
    config[:port] = port
  end

end.parse!

Daemons.run_proc('volcano_ftp', {:log_output => true,}) do
    ftp = VolcanoFtp.new(config[:port])
    ftp.run
end
