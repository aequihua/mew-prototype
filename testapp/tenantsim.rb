# Ruby code to test calls to the MEW service
# This is a simulation of a Tenant number X, who runs a random number of requests every random X seconds

# require 'soap/rpc/driver'  
# driver = SOAP::RPC::Driver.new('http://127.0.0.1:12321/', 'urn:memcached')  
# driver.add_method('mset', 'tenantID', 'primaryKey','value')  
# driver.add_method('mget', 'tenantID', 'primaryKey')  

require '../abstraction/logicalservice'
require 'active_support/secure_random'

class TenantSimulator
	attr_accessor :tenantID, :service

	def initialize(tenantID)
		if tenantID.class.name != "Fixnum"
			puts 'Wrong argument (tenantID, numbertimes must be both integer numbers)'
			return false
		end
		@tenantID = tenantID
		puts "Created new simulator for tenant #{tenantID}. You can run the tests using the run_test01 method"
	end
	
	def generate_pkey
		return ActiveSupport::SecureRandom.base64(16)
	end

	def run_test(numbertimes, baserequests, basewaiting)
		@service = LogicalService.new('memcached','urn:memcached','localhost',12321+@tenantID)
	
		puts 'Running the client calls ' + numbertimes.to_s + ' times...'
		numbertimes.times { |idx|
			numrequests = Random.new.rand(1..baserequests)
			puts "Calling the logical service #{numrequests} times..."
			
			numrequests.times { |idx2|
				yield
			}

			timesleep=Random.new.rand(1..basewaiting)
			puts "Sleeping #{timesleep} seconds..."
			sleep(timesleep)
		}
		
		@service.shutdown
	end

	def test01(numbertimes, baserequests=10, basewaiting=30)
		run_test(numbertimes,baserequests,basewaiting) { |pkey,result|
			pkey = generate_pkey
			valor = "valor_"+pkey
			puts "voy a asignar este valor:" + valor
			@service.mset(@tenantID, pkey, valor)
			result = @service.mget(@tenantID, pkey)
			puts 'Call result = ' + result.to_s
		}
	end

	def test02(numbertimes, baserequests=10, basewaiting=30)
		run_test(numbertimes,baserequests,basewaiting) { |pkey|
			pkey = generate_pkey
			@service.mset(@tenantID, pkey, generate_pkey)
		}
	end
	
end

# run a chain of tests based on the tenant numbers provided
  
  if ARGV.size != 4
	puts "4 parameters are needed: tenantNo, #times of test, #requests per time, #seconds to wait"
	exit(1)
  end
  
  # begin
	tenant = ARGV[0].to_i
	nrtimes = ARGV[1].to_i
	basereq = ARGV[2].to_i
	waittime = ARGV[3].to_i
	
	puts "Running for tenant: #{tenant}"
	tenant=TenantSimulator.new(tenant)
	tenant.test01(nrtimes,basereq,waittime)
	puts '\nNow waiting for a random period...\n'
	sleep Random.new.rand(5..150)  # Random delay between each burst of requests
  # rescue => e
	# puts "Error with the parameters, probably non-integer values were provided."
	# puts e.message
  # end



