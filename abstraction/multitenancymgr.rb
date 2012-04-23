require_relative './observer'
require_relative './servicebroker'
require_relative './cloudsvcpolicy'

class MultitenancyManager
	attr_accessor :observers, :circle, :requests, :policy, :logicalService, :sb
	
	def initialize(logicalsvc)
		@logicalService = logicalsvc
		@sb = ServiceBroker.new(@logicalService)
		@observers = Hash.new
		add_observer(@logicalService, DemandRecorder.new(@logicalService))
		add_observer('MMScrn_'+@logicalService, ScreenLogger.new)
		add_observer('MMLog_'+@logicalService, PlainLogger.new('MM_'+@logicalService+'.log'))		
		@requests = 0
		@policy = CloudSvcPolicy.new
		return 'ok'
	end
	
	def refresh_circle		
		@sb.load_circle   # Refresh the circle in order to have the most accurate information before each call is made
		@circle = @sb.circle
	end
	
	def get_physical_service(primaryKey, size, tenantID)
	# Return which physical server needs to be contacted to address the request sent by the user
	# According to the consistent hashing algorithm
	
		refresh_circle   # Ask the servicebroker to provide the current circle
		
		hash = hash_key(tenantID.to_s + primaryKey)
		apphash = hash

		@requests = @requests + 1   #Increase the number of requests being sent
		
		if @requests > @policy.max_requests_per_server   # Check if the requests are valid
			self.notify_observers(@logicalService, tenantID, @requests, size, WARN, "Multitenancy manager: Denied physical service for "+ primaryKey + " due to limit of requests policy" )
			return nil,apphash
		end
		
		if @circle.empty?
			objtoreturn = nil
		elsif @circle.size == 1
			objtoreturn = @circle.first.last
		elsif @circle[hash]  # If the key is there, let's return it.
			objtoreturn = @circle[hash]
		else   # If not, we need to find the next closest from it!
			hash = @circle.keys.select() { |k| k > hash }.sort.first
			if hash.nil?
				objtoreturn= @circle.first.last
			else
				objtoreturn= @circle[hash]
			end
		end
		
 	    self.notify_observers(@logicalService, objtoreturn.physicalService, tenantID, primaryKey, apphash, objtoreturn.physicalService, @requests, size, INFO, "Multitenancy manager: Obtained physical service for "+ primaryKey + " as physserver = " + objtoreturn.physicalService)
		
		return objtoreturn, apphash
	end
	
	def hash_key(x)
	  require 'digest/md5'
	  return Digest::MD5.hexdigest(x)
	end

	def add_observer(name, obs)
		@observers[name] = obs
	end

	def remove_observer(name)
		@observers.delete(name)
	end

	def notify_observers(logicalsvc, physicalsvc, tenantID, primaryKey, physicalKey, resolver, qtyrequests, sizerequests, eventType, msg)
		@observers.each { |obs|
			puts obs[1].class.name
			result = case obs[1].class.name
				when "DemandRecorder" then obs[1].updateSubject(logicalsvc, tenantID, primaryKey, physicalKey, resolver, qtyrequests, sizerequests, msg)
				when "ServerLog" then obs[1].updateSubject(physicalssvc, eventType, msg)
				when "ScreenLogger" then obs[1].updateSubject(eventType, logicalsvc, msg)
				when "PlainLogger" then obs[1].updateSubject(eventType, logicalsvc, msg)				
				else nil
			end
		}
	end

end

