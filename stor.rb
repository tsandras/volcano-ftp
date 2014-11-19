def ftp_stor(args)
    @cs.write "150 Opening ASCII mode data connection for file stor\r\n"
    file = File.new(args, a)
    while chunk = @tsocket.read(1024)
      file.write(chunk)
    end
    @cs.write "226 Transfer complete.\r\n"
end
