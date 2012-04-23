# WEB SERVICES
    require 'logger'  
    require 'soap/rpc/standaloneServer'  
    class MyServer < SOAP::RPC::StandaloneServer  
      def initialize(* args)  
        super  
        add_method(self, 'sayhelloto', 'username')  
        # create a log file  
        @log = Logger.new("soapserver.log", 5, 10*1024)  
      end  
      def sayhelloto(username)  
        t = Time.now  
        @log.info("#{username} logged on #{t}")  
        "Hello, #{username} on #{t}."  
      end  
    end  
      
    server = MyServer.new('RubyLearningServer','urn:mySoapServer','localhost',12321)  
    trap('INT') {server.shutdown}  
    server.start  	  

	#WEB SERVICE INVOKER
require 'soap/rpc/driver'  
driver = SOAP::RPC::Driver.new('http://127.0.0.1:12321/', 'urn:mySoapServer')  
driver.add_method('sayhelloto', 'username')  
puts driver.sayhelloto('RubyLearning')  	
	
# DATABASE ACCESS CODE
  require 'DB'
  
  db = DBrb.new("my_dbi_driver_string", "usr", "credentials")

	 
  # return single value or array if a single row is selected
  i = db.sql("select max(id) from some_table")
  n, l =  db.sql("SELECT first, last FROM some_name WHERE id = ?", 1000)
  
  db.sql("SELECT first, last FROM some_name WHERE id < ?", 1000) do |row|
          puts "#{row.first} #{row.last}"
          # in case of conflicts with existing methods, you can use:
          row["last"]
  end
  
  # MUTEX
  require 'thread'
semaphore = Mutex.new

a = Thread.new {
  semaphore.synchronize {
    # access shared resource
  }
}

b = Thread.new {
  semaphore.synchronize {
    # access shared resource
  }
}

# SQLITE USAGE

# array of rows
require 'sqlite'

  db = SQLite::Database.new( "test.db" )
  rows = db.execute( "select * from test" )

# block to process the rows
 require 'sqlite'

  db = SQLite::Database.new( "test.db" )
  db.type_translation = true
  columns, *rows = db.execute2( "select * from test" )

  # or use a block:

  columns = nil
  db.execute2( "select * from test" ) do |row|
    if columns.nil?
      columns = row
    else
      # process row
    end
  end

# non-query statements
  db.execute( "insert into table values ( ?, ? )", *bind_vars )


# OBTAIN RESPONSE FROM EXTERNAL PROGRAM
#!/usr/bin/env ruby
 
 `ping #{ARGV[0]}`
 
 if $? == 0
   puts "Ping was successful"
 else
   puts "Ping was not successful"
 end
 
 # MD5 DIGEST
 
   #!/usr/bin/ruby -w
  require 'digest/md5'
  filename = 'MD5.rdoc'

  all_digest = Digest::MD5.hexdigest(File.read(filename))

  incr_digest = Digest::MD5.new()
  file = File.open(filename, 'r')
  file.each_line do |line|
    incr_digest << line
  end

  puts incr_digest.hexdigest
  puts all_digest
  
#RANDOM NUMBERS
  
  r = Random.new
r.rand(10...42) # => 22

10.times.map{ 20+Random.rand(11) } 


# OBTAIN DISTANCE TO HOST

#!/usr/bin/ruby

require 'timeout'
require 'socket'
include Socket::Constants

def random_port
	1024 + rand(64511)
end

if ARGV[0].nil?
	puts "Usage: rubyroute host" ; exit 1 
end

begin
	myname = Socket.gethostname 
rescue SocketError => err_msg
	puts "Can't get my own host name (#{err_msg})." ; exit 1
end

puts "Tracing route to #{ARGV[0]}"

ttl           = 1
max_ttl       = 255
localport     = random_port
dgram_sock    = UDPSocket::new

begin
	dgram_sock.bind( myname, localport )
rescue 
	localport = random_port
	retry
end

icmp_sock     = Socket.open( Socket::PF_INET, Socket::SOCK_RAW, Socket::IPPROTO_ICMP )
icmp_sockaddr = Socket.pack_sockaddr_in( localport, myname )
icmp_sock.bind( icmp_sockaddr )

begin
	dgram_sock.connect( ARGV[0], 999 )
rescue SocketError => err_msg
	puts "Can't connect to remote host (#{err_msg})." ; exit 1
end

until ttl == max_ttl
	dgram_sock.setsockopt( 0, Socket::IP_TTL, ttl )
	dgram_sock.send( "RubyRoute says hello!", 0 )

	begin
		Timeout::timeout( 1 ) {
			data, sender = icmp_sock.recvfrom( 8192 )
			# 20th and 21th bytes of IP+ICMP datagram carry the ICMP type and code resp.
			icmp_type = data.unpack( '@20C' )[0]
			icmp_code = data.unpack( '@21C' )[0]
			# Extract the ICMP sender from response.
			puts "TTL = #{ttl}:  " + Socket.unpack_sockaddr_in( sender )[1].to_s
			if    ( icmp_type == 3 and icmp_code == 13 )
					puts "'Communication Administratively Prohibited' from this hop."
			# ICMP 3/3 is port unreachable and usually means that we've hit the target.
			elsif ( icmp_type == 3 and icmp_code == 3 )
					puts "Destination reached. Trace complete."
					exit 0
			end
		}
	rescue Timeout::Error
		puts "Timeout error with TTL = #{ttl}!"
	end

	ttl += 1
end

12340000

# MANEJO DE THREADS

    puts Thread.main  
    puts ""  
    t1 = Thread.new {sleep 100}  
    Thread.list.each {|thr| p thr }  
    puts "Current thread = " + Thread.current.to_s  
    puts ""  
      
    t2 = Thread.new {sleep 100}  
    Thread.list.each {|thr| p thr }  
    puts Thread.current  
    puts ""  
      
    Thread.kill(t1)  
    Thread.pass                          # pass execution to t2 now  
    t3 = Thread.new do  
      sleep 20  
      Thread.exit                        # exit the thread  
    end  
    Thread.kill(t2)                      # now kill t2  
    Thread.list.each {|thr| p thr }  
      
    # now exit the main thread (killing any others)  
    Thread.exit  

  