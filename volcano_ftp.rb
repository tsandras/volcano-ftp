require "socket"
require "yaml/store"
include Socket::Constants

# Volcano FTP contants
BINARY_MODE = 0
ASCII_MODE = 1

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

    if port == nil
       port = PORT
    end
    @socket = TCPServer.new(HOST, port)
    @socket.listen(42)

    @pids = []
    @transfert_type = BINARY_MODE
    @tsocket = nil
    puts "Server ready to listen for clients on port #{port}"
  end

  def ftp_pwd(args)
    dir = ROOT
    @cs.write "257 \"#{dir}\" is current directory.\r\n"
    0
  end

  def ftp_cwd(args)
    puts args
    Dir.chdir(args)
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
            puts "[#{Process.pid}] Client sent : --#{line}--"
            ####
	  #  puts "------------- #{line} ----------"
            args = /^[\n\s\t]*(\w+)[\s\t\n]+(.*)/.match(line)
	  #  puts "......................... #{args}............................."
	    if not args.nil? then
	       cmd = "ftp_#{args[1].downcase}"
	       if not respond_to? :"#{cmd}" then
	       cmd = "ftp_502"
	       end
	    end
	    method = method(:"#{cmd}")
	   # puts method
	    if method.call(args[2]) == -1 then break
	    end
            ####
          end
          puts "[#{Process.pid}] Killing connection from #{peeraddr[2]}:#{peeraddr[1]}"
          @cs.close
          Kernel.exit!
        end
      end
    end
  end
end
