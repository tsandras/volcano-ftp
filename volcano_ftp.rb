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

    if port == nil
       port = PORT
    end

    @socket = TCPServer.new(HOST, port)
    @socket.listen(42)

    Dir.chdir(ROOT)
    @pids = []
    @transfert_type = BINARY_MODE
    @tsocket = nil
    puts "Server ready to listen for clients on port #{port}"
  end

  def ftp_pwd(args)
    dir = Dir.getwd
    @cs.write "257 \"#{dir}\" is current directory.\r\n"
    0
  end

  def ftp_cwd(args)
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
     # @cs.write "150 Opening data connection for #{Dir.pwd}.\r\n"
      #  if not @tsocket.nil?
       #         if @tsocket.instance_of?(TCPServer)
        #                @ts, = @tsocket.accept
         #       else
          #              @ts = @tsocket
           #     end
            #    @ts.write `ls -la #{Dir.pwd}`
             #   @ts.close
        #else
        #        @cs.write `ls -la #{Dir.pwd}`
       # end
       # @cs.write "226 Transfer complete.\r\n"
       # @tsocket = nil
       # 0
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
    @cs.write "150 Opening ASCII mode data connection for file stor\r\n"
    file = File.new(args, "a")
    while chunk = @tsocket.read(1024)
      file.write(chunk)
    end
    @cs.write "226 Transfer complete.\r\n"
    0
  end

  def ftp_retr(args)
    @cs.write "125 Opening data connection for file retr.\r\n"
    @tsocket.print File.read("#{Dir.pwd}/#{args.strip}")
    @cs.write "226 transfer complete"
    @tsocket.close
    0
  end

  def ftp_dele(args)
    File.delete(args)
    @cs.write "250 DELE COMMAND Successful.\r\n"
    0
  end

  def ftp_rmd(args)
    Dir.delete args.strip
    @cs.write "250 RMD COMMAND Successful.\r\n"
  end

  def ftp_mkd(args)
    Dir.mkdir args.strip
    @cs.write "250 MKD COMMAND Successful.\r\n"
    0
  end

  def ftp_rnfr(args)
      @originalfile = args.strip
      @cs.write "250 RNFR COMMAND Successful.\r\n"
      0
  end

  def ftp_rnto(args)
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
