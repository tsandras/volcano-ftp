require "socket"
require "yaml/store"
include Socket::Constants

# Volcano FTP contants
BINARY_MODE = 0
ASCII_MODE = 1
SIZE = 1024 * 1024 * 10
CONFIGS = YAML.load_file("config.yml")

MIN_PORT = CONFIGS['MIN_PORT']
MAX_PORT = CONFIGS['MAX_PORT']
HOST = CONFIGS['HOST']
PORT = CONFIGS['PORT']
ROOT = CONFIGS['ROOT']
LOG  = CONFIGS['LOG']

# Volcano FTP class
class VolcanoFtp
  def initialize(port)
    if File.exists?ROOT
       if File.readable?ROOT
       	  if File.directory?ROOT
           @f = File.open(LOG, "a+")
    	     Dir.chdir(ROOT)
	         @socket = TCPServer.new(HOST, port)
    	     @socket.listen(42)
    	     @pids = []
    	     @transfert_type = BINARY_MODE
    	     @tsocket = nil
    	     puts "Server ready to listen for clients on port #{port}"
	  else
	   	puts "#{ROOT} : Is not a directory"
	  end
       else
	  puts "#{ROOT} is not readable"
       end
    else
       puts "#{ROOT} : No such file or directory"
    end

    if port == nil
       port = PORT
    end
  end

  def ftp_pwd(args)
    dir = Dir.getwd
    @cs.write "257 \"#{dir}\" is current directory.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 257 #{dir} is current directory")
    0
  end

  def ftp_cwd(args)
    unless Dir.exists?(args.strip)
      @cs.write "550 No such directory #{args.strip}.\r\n"
      log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 550 No such directory #{args.strip}")
      return 0
    end
    Dir.chdir args.strip
    @cs.write "250 CWD command successful.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 250 CWD command successful")
    0
  end

  def ftp_type(args)
    args = /^[\n\s\t]*(\w+)[\s\t\n]*$/.match(args)
    if args[1] == "I"
       @cs.write "200 Type set to I.\r\n"
    elsif args[1] == "A"
       @cs.write "200 Type set to A.\r\n"
    end
    0
  end

  def ftp_pasv(args)
    @cs.write "227 PASV command successful.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 227 PASV command successful")
    0
  end

  def ftp_port(args)
    args = /(\d{1,3},\d{1,3},\d{1,3},\d{1,3}),(\d{1,3}),(\d{1,3})/.match(args)
    ip = args[1].gsub(/,/, ".")
    port = args[2].to_i() * 256 + args[3].to_i()
    @tsocket = TCPSocket.new(ip, port)
    @cs.write "200 PORT command successful.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 200 PORT command successful")
    0
  end

  def ftp_syst(args)
    @cs.write "215 UNIX Type: L8.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 215 UNIX Type: L8")
    0
  end

  def ftp_noop(args)
    @cs.write "200 Don't worry my lovely client, I'm here ;)"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 200 Don't worry my lovely client, I'm here ;)")
    0
  end

  def ftp_user(args)
    @cs.write "331 User name okay, need password.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 331 User name okay, need password")
    0
  end

  def ftp_pass(args)
    @cs.write "230 User logged in, proceed.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 230 User logged in, proceed")
    0
  end

  def ftp_502(*args)
    puts "Command not found"
    @cs.write "502 Command not implemented.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 502 Command not implemented")
    0
  end

  def ftp_exit(args)
    @cs.write "221 Thank you for using Volcano FTP.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 221 Thank you for using Volcano FTP")
    -1
  end

  def ftp_list(args)
    if args == ""
       args = Dir.pwd
    end
    unless Dir.exists?(args)
      @cs.write "550 No such directory #{args}.\r\n"
      log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 550 No such directory #{args}")
      return 0
    end
    resp = `ls -l #{args}`
    @cs.write "125 Opening data connection for #{args}.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 125 Opening data connection for #{args}")
    resp.split("\n").each {|file|
      @tsocket.write "#{file}\r\n"
    }
    @tsocket.close
    @cs.write "226 Transfer complete.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 226 Transfer complete")
    0
  end

  def ftp_stor(args)
    if Dir.exists?(args)
      @cs.write "550 A directory #{args} already.\r\n"
      log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 550 A directory #{args} already")
      return 0
    end
    @cs.write "150 Opening ASCII mode data connection for file stor.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 150 Opening ASCII mode data connection for file stor")
    file = File.new(args, "w")
    while chunk = @tsocket.read(2048)
      file.write(chunk)
    end
    @cs.write "226 Transfer complete.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 226 Transfer complete")
    0
  end

  def ftp_retr(args)
    @cs.write "125 Opening data connection for file retr.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 125 Opening data connection for file retr")
    args = args.strip
    unless File.exists?(args)
      @cs.write "550 No such file #{args}.\r\n"
      log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 550 No such file #{args}")
      return 0
    end
    unless File.readable?(args)
      @cs.write "550 Can't read file #{args}.\r\n"
      log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 550 Can't read file #{args}")
      return 0
    end
    File.open(args) do |f|
      while(chunk = f.read(2048))
        @tsocket.write(chunk)
      end
    end
    @cs.write "226 transfer complete.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 226 transfer complete")
    @tsocket.close
    0
  end

  def ftp_dele(args)
    args = args.strip
    unless File.exists?(args)
      @cs.write "550 No such file #{args}.\r\n"
      log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 550 No such file #{args}")
      return 0
    end
    File.delete(args)
    @cs.write "250 DELE COMMAND Successful.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 250 DELE COMMAND Successful")
    0
  end

  def ftp_rmd(args)
    args = args.strip
    unless Dir.exists?(args)
      @cs.write "550 No such directory.\r\n"
      log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 550 No such directory")
      return 0
    end
    Dir.delete args
    @cs.write "250 RMD COMMAND Successful.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 250 RMD COMMAND Successful")
    0
  end

  def ftp_mkd(args)
    if Dir.exists?(args)
      @cs.write "550 Directory #{args} already exists.\r\n"
      log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 550 Directory #{args} already exists")
      return 0
    end
    Dir.mkdir args.strip
    @cs.write "250 MKD COMMAND Successful.\r\n"
    log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 250 MKD COMMAND Successful")
    0
  end

  def ftp_rnfr(args)
      unless File.exists?(args)
        @cs.write "550 No such file #{args}.\r\n"
        log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 550 No such file #{args}")
        return 0
      end
      @originalfile = args.strip
      @cs.write "250 RNFR COMMAND Successful.\r\n"
      log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 250 RNFR COMMAND Successful")
      0
  end

  def ftp_rnto(args)
      if File.exists?(args)
        @cs.write "550 File #{args} already exists.\r\n"
        log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 550 File #{args} already exists")
        return 0
      end
      newfile = "#{Dir.pwd}/#{args}"
      newfile.strip
      File.rename(@originalfile, newfile)
      @cs.write "250 RNTO COMMAND Successful.\r\n"
      log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# response => 250 RNTO COMMAND Successful")
      0
  end

  def log(message)
    @f.puts(message)
  end

  def run
    while (42)
      selectResult = IO.select([@socket], nil, nil, 0.1)
      if selectResult == nil or selectResult[0].include?(@socket) == false
        @pids.each do |pid|
          if not Process.waitpid(pid, Process::WNOHANG).nil?
            @pids.delete(pid)
          end
        end
        p @pids
      else
        @cs,  = @socket.accept
        peeraddr = @cs.peeraddr.dup
        @pids << Kernel.fork do
          puts "[#{Process.pid}] Instanciating connection from #{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}"
          log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# [#{Process.pid}] Instanciating connection")
          @cs.write "220-\r\n\r\n Welcome to Volcano FTP server !\r\n\r\n220 Connected\r\n"
          while not (line = @cs.gets).nil?
            puts "[#{Process.pid}] Client sent : --#{line.strip}--"
            log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# send => #{line.strip}")
            args = /^[\n\s\t]*(\w+)[\s\t\n]+(.*)/.match(line)
            if not args.nil? then
              cmd = "ftp_#{args[1].downcase.strip}"
              if not respond_to? :"#{cmd}" then
                cmd = "ftp_502"
              end
            end
            method = method(:"#{cmd}")
            if method.call(args[2].strip) == -1 then break
            end
          end
          puts "[#{Process.pid}] Killing connection from #{peeraddr[2]}:#{peeraddr[1]}"
          log("#{Time.now.to_s} ##{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}# [#{Process.pid}] Killing connection")
          @f.close
          @cs.close
          Kernel.exit!
        end
      end
    end
  end
end
