require_relative '../data/dbaccessor'
require_relative '../physical/physicalservice'
require_relative './observer'
require_relative './cloudsvcpolicy'

class ServiceBroker
	attr_accessor :observers, :circle, :logicalService, :heuristic, :bValid
	require 'thread'
	
	def initialize(logicalService)
		@observers = Hash.new
		@circle = Hash.new
		@logicalService = logicalService
		policy = CloudSvcPolicy.new
		add_observer(logicalService, ServerLog.new(logicalService))
		add_observer('SBScrn_'+logicalService, ScreenLogger.new)
		add_observer('SBLog_'+logicalService, PlainLogger.new('SB_'+logicalService+'.log'))		
		@heuristic = policy.service_broker_algorithm
		
		# Validate the presence of the logical service in the tables
		logicalsvcid = DBAccess.new.getcolumnvalue("id", "LogicalServices", "logicalsvcname='"+logicalService+"'")
		@bValid = (not logicalsvcid.nil?)
		if not @bValid
			puts 'Service ' + logicalService + ' does not exist in tables, invalid Service Broker'
		else
			load_circle
		end
		
		return 'ok'
	end
	
	def load_circle
	# Read the physical services that exist on the database to create the circle accordingly
	# Useful for failure recovery
		rows = get_service_list
		
		rows.each { |row|
			supplier = DBAccess.new.getrows("select * from ServiceSuppliers where id=" + row["supplierid"].to_s)
			physvc = PhysicalService.new(0, "", 0, "")
			physvc.populate(row)
			@circle[get_hashkey_for_service(physvc.physicalService)] = physvc
		}
		
	end
	
	def get_hashkey_for_service(physvcname)
		number = Random.rand.to_s  # Obtain a random number to take part as the primary key and provoke "distance" between physical services
	# return hash_key(physvcname+number)
		return hash_key(physvcname)
	end

	def contract_service	
		if not @bValid
			return -1
		end
	    		
        if  @heuristic == "Price"

               contract = SvcContractContext.new(SvcContractByPrice.new)

        elsif  @heuristic == "Location"

               contract = SvcContractContext.new(SvcContractByLocation.new)

        else
               return 0
        end

		physvc = nil
		
		# semaphore = Mutex.new

		# a = Thread.new {
		  # semaphore.synchronize {
				physvc = contract.executeStrategy(@logicalService)
				if not physvc.nil?
					physvc.start_service
					@circle[get_hashkey_for_service(physvc.physicalService)] = physvc
					notify_observers(INFO,physvc.physicalService, "Service contracted successfully : " + @logicalService + " physname=" + physvc.physicalService)
					return 0
				else
					notify_observers(INFO,@logicalService, "No supplier found to provide : " + @logicalService)
					return -1
				end
		  # }
		# }
	end

	def cancel_service
	# Shutdown ANY ONE of the physical services in the circle array. If more than one physical service instance is to 
	# be shut down, the caller must call this method one time per instance
		if not @bValid or @circle.empty?
			return -1
		end
	
		# semaphore = Mutex.new

		# a = Thread.new {
		  # semaphore.synchronize {
			deleted_service = @circle.shift if @circle.size>0
			if not deleted_service.nil?
				notify_observers(INFO, deleted_service[1].physicalService, "Service cancelled successfully : " + deleted_service[1].physicalService)
				deleted_service[1].stop_service  # Terminate the service physically
				return 0
			else
				notify_observers(WARN,"unknown", "Service could not be cancelled ")				
				return 1
			end
		  # }
		# }	
	end
	
	def hash_key(x)
	  require 'digest/md5'
	  return Digest::MD5.hexdigest(x)
	end

	def get_status
	# Obtain a list of all the physical services and their respective status
		statushash = Hash.new

		if not @bValid
			return statushash
		end
		
		rows = get_service_list				
		
		rows.each { |svc| 
			addtocheck = svc["serviceURI"]
			status = ping(addtocheck)
		    notify_observers(INFO,svc["physicalsvcname"],"Validated presence of physical service : " + svc["physicalsvcname"] + ", status = "+status.to_s)
			if status == 0
				msg = "Working"
			else
				msg = "Down"
			end				
			statushash[svc["physicalsvcname"]] = msg
		}
		
		return statushash
	end
	
	def ping(target)
	# Technical implementation of how to check the presence of the service in the network
		 `ping #{target}`
		 
		 if $? == 0
		   return 0
		 else
		   return -1
		 end	
	end

	def get_service_list
	# Get the list of physical services that are created for the given logical service
		if not @bValid
			return nil
		end
	
		logicalsvcid = DBAccess.new.getcolumnvalue("id", "LogicalServices", "logicalsvcname='"+@logicalService+"'")
		if not logicalsvcid.nil?
			query = "Select * from physicalservices where logicalsvcid="+ logicalsvcid.to_s
			svclist = DBAccess.new.getrows(query)
			if not svclist.nil?
				notify_observers(INFO,@logicalService, "Provided service list : " + svclist.size.to_s)
				return svclist
			end			
		end
		return Hash.new
	end

	def add_observer(name, obs)
		@observers[name] = obs
	end

	def remove_observer(name)
		@observers.delete(name)
	end

	def notify_observers(eventType, physvc, msg)
		@observers.each { |obs|
			result = case obs[1].class.name
				when "ServerLog" then obs[1].updateSubject(physvc, eventType, msg)
				when "ScreenLogger" then obs[1].updateSubject(eventType, physvc, msg)
				when "PlainLogger" then obs[1].updateSubject(eventType, physvc, msg)				
				else nil
			end
		}
	end
	
end

class SvcContractContext
	attr_accessor :strategy
	
	def initialize(strategyspec)
		self.strategy = strategyspec	
	end

	def executeStrategy(svcname)
      return @strategy.contract_service(svcname)	
	end
end

class SvcContractStrategy
	
	def contract_service(svcname)
	end
	
	def getsupplierlist(svcname, ordercriteria)
	# Obtain a current list of suppliers WHO HAVE CAPACITY available (instances to provide) and order it according to the order criteria provided
		logicalsvcid = DBAccess.new.getcolumnvalue("id", "LogicalServices", "logicalsvcname='"+svcname+"'")
		if not logicalsvcid.nil? and not ordercriteria.nil?
			query = "Select * from ServiceSuppliers where ID in (select supplierid from SuppliersLogicalSvcs where logicalsvcid="+ logicalsvcid.to_s + " and unitscapacity > unitsused"
			query = query + ") order by " + ordercriteria.to_s
			rows = DBAccess.new.getrows(query)
			if not rows.empty?
				return rows
			end
	    else
			puts "Logical service ID is not registered for : " + svcname
	    end		
		return Hash.new
	end
	
	def getbestsupplier(svcname, supplierlist)
	# Iterate in the supplier list provided in such a way that the first supplier that meets the criteria is selected and returned
		physsvc = nil
		
		logicalsvcid = DBAccess.new.getcolumnvalue("id", "LogicalServices", "logicalsvcname='"+svcname+"'")
		if logicalsvcid.nil? 
			return nil
		end
		
		supplierlist.each { |supplier| 
			if supplier["suppliertype"] == "internal" 
				creator = InternalSvcCreator.new(supplier["id"], supplier["supplierdistance"],logicalsvcid)
			else
				creator = ExternalSvcCreator.new(supplier["id"], supplier["supplierdistance"], logicalsvcid)
			end
	 
			physsvc = creator.create(svcname)   # Physical service instance is created as <name>_<N>

			break if not physsvc.nil? 
		 }	
		 return physsvc
	end
end

class SvcContractByPrice < SvcContractStrategy
	def contract_service(svcname)
	# Find the “cheapest” supplier with capacity available
		supplierlist = getsupplierlist(svcname, "suppliercost")
	
	# Invoke the factory according to the specific service that is to be “recruited”
		physsvc = getbestsupplier(svcname, supplierlist)

	# Return the service name (the physical)
		return physsvc
	end
end

class SvcContractByLocation < SvcContractStrategy
	def contract_service(svcname)
	# Find the “closest” supplier with capacity available
		supplierlist = getsupplierlist(svcname, "supplierdistance")
	
	# Invoke the factory according to the specific service that is to be “recruited”
		physsvc = getbestsupplier(svcname, supplierlist)

	# Return the service name (the physical)
		return physsvc
	end
end

