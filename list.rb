def list_ftp(args)
    @cs.write "150 Opening data connection for #{args}.\r\n"
    resp = 'ls -la #{args}'
    @tsocket.write resp
    @cs.write "226 Transfer complete.\r\n"
    @tsocket.close
end
