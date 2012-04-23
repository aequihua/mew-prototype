require 'digest/md5'
require_relative '../abstraction/cloudsvcpolicy'
require_relative '../abstraction/tenant'

class ServiceClient 

# Properties
    attr_accessor :paasname,:paasCredentials, :tenantID, :logwebservice, :client
	
	def initialize		
		@paasname = CloudSvcPolicy.new.paas_name
		
		@client  = case @paasname
			when "CloudFoundry" then ServiceClientCloudFoundry.new
			when "Generic" then ServiceClientGeneric.new
			else ServiceClientUnauthenticated.new
		end
				
		@client.service_logon
		
		if @client.tenantID.nil?
			@client = ServiceClientUnauthenticated.new
		end
	end

# Methods
    def service_logon
    # Line to be adapted to CloudFoundry
        get_paasParams             	   
		require 'soap/rpc/driver'  
		puts "Demo de llamado por web service"
		@logwebservice = SOAP::RPC::Driver.new('http://127.0.0.1:12321/', 'urn:memcached')  
		@logwebservice.add_method('mset', 'tenantid', 'pkey', 'value')  
		@logwebservice.add_method('mget', 'tenantid', 'pkey')  	   
		puts "tenantid es"
		puts @tenantID
    end
	
	def set(pkey, value)
		return @client.set(pkey,value)
	end
	
	def get(pkey)
		return @client.get(pkey)
	end
	
	def service_logoff()
		record_log("User logged out "  + tenantID)
	end
	
	def get_paasParams()
	# Superclass method, no code here
	end
    	
	def self.record_log(msg)
		puts msg
	end

end


class ServiceClientUnauthenticated < ServiceClient
	def initialize
	end
	
	def set(pkey, value)
		record_log("Function call invalid "  + pkey)
		puts("Function SET not available, need valid authentication first")
	end
	
	def get(pkey)
		record_log("Function call invalid "  + pkey)
		puts("Function GET not available, need valid authentication first")
	end
end

class ServiceClientAuthenticated < ServiceClient
	def initialize
	end
	
	def set(pkey, value)
		return @logwebservice.mset(@tenantID,pkey,value)
	end
	
	def get(pkey)
		return @logwebservice.mget(@tenantID,pkey)
	end
end

class ServiceClientCloudFoundry < ServiceClientAuthenticated
	def initialize
	end
	
	def get_paasParams()
	# ADAPT FOR CLOUDFOUNDRY
		@tenantID = Random.new.rand(1..10)
	end
end

class ServiceClientGeneric < ServiceClientAuthenticated
	def initialize
	end
	
	def get_paasParams()
		@tenantID = Random.new.rand(1..10)
	end
end
