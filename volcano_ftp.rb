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

# Volcano FTP class
class VolcanoFtp
  def initialize(port)
    # Prepare instance

    if File.exists?ROOT
       if File.readable?ROOT
       	  if File.directory?ROOT
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
    0
  end

  def ftp_cwd(args)
    unless Dir.exists?(args.strip)
      @cs.write "550 No such directory #{args.strip}.\r\n"
      return -1
    end
    Dir.chdir args.strip
    @cs.write "250 CWD command successful.\r\n"
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
    @cs.write "227 PASV command successful \r\n"
    0
  end

  def ftp_port(args)
    args = /(\d{1,3},\d{1,3},\d{1,3},\d{1,3}),(\d{1,3}),(\d{1,3})/.match(args)
    ip = args[1].gsub(/,/, ".")
    port = args[2].to_i() * 256 + args[3].to_i()
    @tsocket = TCPSocket.new(ip, port)
    @cs.write "200 PORT command successful.\r\n"
    0
  end

  def ftp_syst(args)
    @cs.write "215 UNIX Type: L8\r\n"
    0
  end

  def ftp_noop(args)
    @cs.write "200 Don't worry my lovely client, I'm here ;)"
    0
  end

  def ftp_user(args)
      @cs.write "331 User name okay, need password.\r\n"
    0
  end

  def ftp_pass(args)
    @cs.write "230 User logged in, proceed.\r\n"
    0
  end

  def ftp_502(*args)
    puts "Command not found"
    @cs.write "502 Command not implemented\r\n"
    0
  end

  def ftp_exit(args)
    @cs.write "221 Thank you for using Volcano FTP\r\n"
    -1
  end

  def ftp_list(args)
    if args == ""
       args = Dir.pwd
    end
    unless Dir.exists?(args)
      @cs.write "550 No such directory #{args}.\r\n"
      return -1
    end
    resp = `ls -l #{args}`
    @cs.write "125 Opening data connection for #{args}.\r\n"
    #@tsocket.write resp
    resp.split("\n").each {|file|
      @tsocket.write "#{file}\r\n"
    }
    @tsocket.close
    @cs.write "226 Transfer complete.\r\n"
    0
  end

  def ftp_stor(args)
    if Dir.exists?(args)
      @cs.write "550 A directory #{args} already.\r\n"
      return -1
    end
    @cs.write "150 Opening ASCII mode data connection for file stor\r\n"
    file = File.new(args, "w")
    while chunk = @tsocket.read(2048)
      file.write(chunk)
    end
    @cs.write "226 Transfer complete.\r\n"
    0
  end

  def ftp_retr(args)
    @cs.write "125 Opening data connection for file retr.\r\n"
    args = args.strip
    unless File.exists?(args)
      @cs.write "550 No such file #{args}.\r\n"
      return -1
    end
    unless File.readable?(args)
      @cs.write "550 Can't read file #{args}.\r\n"
      return -1
    end
    File.open(args) do |f|
      while(chunk = f.read(2048))
        @tsocket.write(chunk)
      end
    end
    @cs.write "226 transfer complete\r\n"
    @tsocket.close
    0
  end

  def ftp_dele(args)
    args = args.strip
    unless File.exists?(args)
      @cs.write "550 No such file #{args}.\r\n"
      return -1
    end
    File.delete(args)
    @cs.write "250 DELE COMMAND Successful.\r\n"
    0
  end

  def ftp_rmd(args)
    args = args.strip
    unless Dir.exists?(args)
      @cs.write "550 No such directory.\r\n"
      return -1
    end
    Dir.delete args
    @cs.write "250 RMD COMMAND Successful.\r\n"
    0
  end

  def ftp_mkd(args)
    if Dir.exists?(args)
      @cs.write "550 Directory #{args} already exists.\r\n"
      return -1
    end
    Dir.mkdir args.strip
    @cs.write "250 MKD COMMAND Successful.\r\n"
    0
  end

  def ftp_rnfr(args)
      unless File.exists?(args)
        @cs.write "550 No such file #{args}.\r\n"
        return -1
      end
      @originalfile = args.strip
      @cs.write "250 RNFR COMMAND Successful.\r\n"
      0
  end

  def ftp_rnto(args)
      if File.exists?(args)
        @cs.write "550 File #{args} already exists.\r\n"
        return -1
      end
      newfile = "#{Dir.pwd}/#{args}"
      newfile.strip
      File.rename(@originalfile, newfile)
      @cs.write "250 RNTO COMMAND Successful.\r\n"
      0
  end

  def run
    while (42)
      selectResult = IO.select([@socket], nil, nil, 0.1)
      if selectResult == nil or selectResult[0].include?(@socket) == false
        @pids.each do |pid|
          if not Process.waitpid(pid, Process::WNOHANG).nil?
            ####
            # Do stuff with newly terminated processes here

            ####
            @pids.delete(pid)
          end
        end
        p @pids
      else
        @cs,  = @socket.accept
        peeraddr = @cs.peeraddr.dup
        @pids << Kernel.fork do
          puts "[#{Process.pid}] Instanciating connection from #{@cs.peeraddr[2]}:#{@cs.peeraddr[1]}"
          @cs.write "220-\r\n\r\n Welcome to Volcano FTP server !\r\n\r\n220 Connected\r\n"
          while not (line = @cs.gets).nil?
            puts "[#{Process.pid}] Client sent : --#{line.strip}--"
            f = File.open("test.txt", "a")
            f.puts(line.strip)
            f.close
            args = /^[\n\s\t]*(\w+)[\s\t\n]+(.*)/.match(line)
      	    if not args.nil? then
              # puts "#{args[1].downcase}"
      	      cmd = "ftp_#{args[1].downcase.strip}"
      	      if not respond_to? :"#{cmd}" then
      	        cmd = "ftp_502"
      	      end
      	    end
      	    method = method(:"#{cmd}")
      	   # puts method
      	    if method.call(args[2]) == -1 then break
      	    end
          end
          puts "[#{Process.pid}] Killing connection from #{peeraddr[2]}:#{peeraddr[1]}"
          @cs.close
          Kernel.exit!
        end
      end
    end
  end
end
