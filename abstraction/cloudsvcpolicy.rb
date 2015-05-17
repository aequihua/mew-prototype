class CloudSvcPolicy

	attr_accessor :paas_name, :refresh_frequency, :max_servers, :max_tenants_per_server,
			:max_requests_per_server, :service_broker_algorithm, :demand_estimation_algorithm,
			:database_type,  :database_connection_string, :database_user, :database_pwd, :cloud_config, :verbose,
			:database_host
			
	require ('rubygems')
	require ('parseconfig')

	def initialize
		refreshparams
		return 'ok'
	end
	
	def refreshparams
	# The config file will be of the format parameter = value, such as:
	#    refresh_frequency = 3600
	#	 max_servers = 99
	#    max_tenants_per_server = 100
	# etc.	
	
		begin
			@cloud_config = ParseConfig.new('/Users/aequihua/mew-prototype/abstraction/cloudpolicy.conf')
		rescue Errno::ENOENT 
			puts "The config file you specified was not found"
			exit
		rescue Errno::EACCES 
			puts "The config file you specified is not readable"
			exit
		end
		
	# Read and assign the relevant configuration settings, with defaults if params are omitted
		@paas_name = parseparam('paas_name','str','Generic')
		@refresh_frequency = parseparam('refresh_frequency','int',3600)
		@max_servers = parseparam('max_servers', 'int', 1)
		@max_tenants_per_server = parseparam('max_tenants_per_server','int',5)
		@max_requests_per_server = parseparam('max_requests_per_server','int',5)
		@service_broker_algorithm = parseparam('service_broker_algorithm','str','Price')
		@demand_estimation_algorithm = parseparam('demand_estimation_algorithm','str','Average')
		@database_type = parseparam('database_type','str','sqlite')
		@database_connection_string = parseparam('database_connection_string','str','mew')
		@database_user = parseparam('database_user','str','')
		@database_pwd = parseparam('database_pwd','str','')
		@verbose = parseparam('verbose','str','ERROR')
		@database_host = parseparam('database_host','str','localhost')
	end
	
	def parseparam(param, type, default)
		valor = @cloud_config.params[param] if @cloud_config.params.has_key?(param)
		if not valor.nil?
			valor = case type
				when 'int' then valor.to_i
				when 'float' then valor.to_f
				else valor
			end
		else
			valor = default
		end
		return valor
	end

end
