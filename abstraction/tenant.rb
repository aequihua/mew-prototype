require_relative '../data/dbaccessor.rb'

# Class to handle the tenants as an abstraction of the specific PaaS implementation
# Each PaaS will have its own table or approach to register valid tenants or applications;
# this class is to be used to implement the specific PaaS 

class TenantStrategy
	attr_accessor :tenantID, :tenantName, :tenantVersion, :language
	
	def initialize
		tenantID = 0
		tenantName = ''
		tenantVersion = ''
		language = ''
	end
	
	def exists?(tenantid)
	end

end

class TenantCloudFoundry < TenantStrategy
	def initialize
		super
	end

	def exists?(tenantid)
		rows = DBAccess.new.getrows('select * from Tenants where id='+tenantid.to_s)
		puts "RESULTADO DE PREGUNTAR POR EL TENANT " + tenantid.to_s
		puts rows
		return (rows.size>0)
	end
end

class TenantGeneric < TenantStrategy
	def initialize
		super
	end

	def exists?(tenantid)
		rows = DBAccess.new.getrows('select * from Tenants where id='+tenantid.to_s)
		puts "RESULTADO DE PREGUNTAR POR EL TENANT " + tenantid.to_s
		puts rows
		return (rows.size>0)
	end
end


class Tenant
	attr_accessor :strategy, :Policy

	def exists?(tenantid)
		return @strategy.exists?(tenantid)	
	end
	
	def initialize		
		@Policy = CloudSvcPolicy.new
		
		puts @Policy.paas_name
		
		self.strategy = case @Policy.paas_name
					when "CloudFoundry" then TenantCloudFoundry.new
					else TenantGeneric.new
				 end		
	end
end
