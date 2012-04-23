require 'thread'
require_relative '../data/dbaccessor'
require_relative './servicebroker'
require_relative './cloudsvcpolicy'
require_relative './observer'

class ElasticityManager
	attr_accessor :elasticityEngine, :demandEstimator,:policy, :capacity, :numservers, :allowedtenants, :logicalsvcname, :observers

	def initialize(logicalsvcname)
		@observers = Hash.new
		add_observer(logicalsvcname, CapacityRecorder.new(logicalsvcname))
		add_observer('EMgrScrn_'+logicalsvcname, ScreenLogger.new)
		add_observer('EMgrLog_'+logicalsvcname, PlainLogger.new('Emgr_'+logicalsvcname+'.log'))
		@policy = CloudSvcPolicy.new
		@elasticityEngine = ElasticityEngine.new(logicalsvcname)
		@logicalsvcname = logicalsvcname
		@capacity = 0
		@numservers = 0
		@allowedtenants = 0
	end
	
	def estimate_demand
		method = @policy.demand_estimation_algorithm
		
		if method == "Average"
				@demandEstimator = DemandEstimationContext.new(EstimateByAverage.new)
		elsif  method == "Regression"
				@demandEstimator = DemandEstimationContext.new(EstimateByRegression.new)
		elsif  method == "Interpolation"
				@demandEstimator = DemandEstimationContext.new(EstimateByInterpolation.new)
		else
			   puts "Inadequate demand estimation algorithm " + method
		end

		@demandEstimator.executeStrategy(logicalsvcname)			
	end
	
	def get_current_capacity
		curcapacity = 0
		dbobject = DBAccess.new
		logicalsvcid = dbobject.getcolumnvalue("id", "LogicalServices", "logicalsvcname='"+logicalsvcname+"'")
		if not logicalsvcid.nil?
			rows = DBAccess.new.getrows("select * from CapacityRecords where logicalsvcid = " + logicalsvcid.to_s + " order by id desc limit 1")
			if rows.empty?
				curcapacity = 0
			else
				firstrow = rows[0] 
				curcapacity = firstrow["capacity"]		
			end
		end
		return curcapacity
	end
	
	def adjust_capacity
		   puts "\n\nEntering iteration...\n"
	   
		   capacity = get_current_capacity

		   forecasted_demand =  estimate_demand
		   
		   if forecasted_demand > @policy.max_servers    # Check if servers can be added
				notify_observers(WARN, @numservers, "Elasticity manager: Unable to increase to "+ forecasted_demand.to_s + " servers due to limit of requests policy = " + @policy.max_servers.to_s)					
				forecasted_demand = @policy.max_servers
		   end

		   if (forecasted_demand > capacity)
				 puts "Expand capacity for "+@logicalsvcname+" to reach "+forecasted_demand.to_s+", that is, add "+(forecasted_demand-capacity).to_s
				 num = @elasticityEngine.expand_capacity(forecasted_demand - capacity)   # COMO LO HAGO "BATCH"
				 @numservers = @numservers + num
				 notify_observers(WARN, @numservers, "Elasticity manager: Capacity now is "+ @numservers.to_s + " servers")
		  elsif (forecasted_demand < capacity)
				 puts "Reduce capacity for "+@logicalsvcname+" to reach "+forecasted_demand.to_s+", that is, reduce "+(forecasted_demand-capacity).to_s
				 num = @elasticityEngine.reduce_capacity(capacity - forecasted_demand)  # COMO LO HAGO BATCH
				 @numservers = @numservers - num
				 notify_observers(WARN, @numservers, "Elasticity manager: Capacity now is "+ @numservers.to_s + " servers")
		  end
		  
		  @allowedtenants = @numservers * @policy.max_tenants_per_server  # Keep the number of allowed tenants accurate
		  puts "allowedtenants = " + @allowedtenants.to_s
		  puts "servers running = " + @numservers.to_s
	end
		
	def activate_manager(nrtimes=1)
		nrtimes.times do |idx|
			adjust_capacity
			p "\n\nNow sleeping for " + @policy.refresh_frequency.to_s + " seconds\n"
			sleep(@policy.refresh_frequency)
		end
	end

	def add_observer(name, obs)
		@observers[name] = obs
	end

	def remove_observer(name)
		@observers.delete(name)
	end

	def notify_observers(eventype, capacity, msg)
		@observers.each { |obs|
			result = case obs[1].class.name
				when "CapacityRecorder" then obs[1].updateSubject(@logicalsvcname, capacity, msg)
				when "ServerLog" then obs[1].updateSubject(@logicalsvcname, eventType, msg)
				when "ScreenLogger" then obs[1].updateSubject(eventype, @logicalsvcname, msg)
				when "PlainLogger" then obs[1].updateSubject(eventype, @logicalsvcname, msg)
				else nil
			end
		}
	end
	
end

	
class ElasticityEngine
	attr_accessor :observers, :sb, :policy, :logicalsvcname
	
	def initialize(logicalsvcname)
		@observers = Hash.new
		@logicalsvcname = logicalsvcname
		add_observer(logicalsvcname, CapacityRecorder.new(logicalsvcname))
		add_observer('EEngScrn_'+logicalsvcname, ScreenLogger.new)
		add_observer('EEngLog_'+logicalsvcname, PlainLogger.new('EEng_'+logicalsvcname+'.log'))		
		@sb = ServiceBroker.new(logicalsvcname)
		@policy = CloudSvcPolicy.new
	end
	
	def expand_capacity(n)
	
		semaphore = Mutex.new
		num = 0
		status=0
		# a = Thread.new {
		  # semaphore.synchronize {
			while ((num<n) and (status==0))
				status = @sb.contract_service
				if status == 0
				   num = num + 1
				end
			end
		  # }
		# }
		
		return num
		
	end

	def reduce_capacity(n)
		num = 0
		status = 0
		semaphore = Mutex.new

		# a = Thread.new {
		  # semaphore.synchronize {
				while ((num<n) and status==0)
					status = @sb.cancel_service
					if (status == 0)
						num = num + 1
						break if num>n
					end
				end
				# }
		  # }
		# }
		
		return num
		
	end

	def start_elasticity_engine
	end

	def stop_elasticity_engine
	end

	def add_observer(name, obs)
		@observers[name] = obs
	end

	def remove_observer(name)
		@observers.delete(name)
	end

	def notify_observers(eventype, capacity, msg)
		@observers.each { |obs|
			result = case obs[1].class.name
				when "CapacityRecorder" then obs[1].updateSubject(@logicalsvcname, capacity, msg)
				when "ServerLog" then obs[1].updateSubject(@logicalsvcname, eventType, msg)
				when "ScreenLogger" then obs[1].updateSubject(eventype, @logicalsvcname, msg)
				when "PlainLogger" then obs[1].updateSubject(eventype, @logicalsvcname, msg)				
				else nil
			end
		}
	end
	
end

class DemandEstimationContext
	attr_accessor :strategy

	def executeStrategy(logicalSvcName)
		@strategy.estimate_demand(logicalSvcName)	
	end
	
	def initialize(strategyspec)
		@strategy = strategyspec	
	end
end

class DemandEstimationStrategy
	attr_accessor :policy
	
	def initialize
		@policy = CloudSvcPolicy.new
	end
	
	def estimate_demand
	end
end

class EstimateByAverage < DemandEstimationStrategy
	def estimate_demand(logicalsvcname)
	# Obtain how the demand was within a one hour time segment, 24 hours ago
		logicalsvcid = DBAccess.new.getcolumnvalue("id", "LogicalServices", "logicalsvcname='"+logicalsvcname+"'")
		if not logicalsvcid.nil?
			dbobject = DBAccess.new
			rows = dbobject.getrows("select "+dbobject.isnull("sum(qtyrequests)",0)+" as sumofrecords from DemandRecords where logicalsvcid = "+logicalsvcid.to_s+" and timestamp <= "+dbobject.get_date(-10,0,0)+" and timestamp>= "+dbobject.get_date(-11,0,0))
			if rows[0]["sumofrecords"] == 0
			# If there are no demand records, it is necessary to "force" it to create 1 server
				return 1
			else		
				x = rows[0]["sumofrecords"] / @policy.max_requests_per_server
				return x.ceil
			end
		else
			return 0
		end
	end
end

class EstimateByRegression < DemandEstimationStrategy
	def estimate_demand(logicalsvcname)
# This method is left empty, the implementation will be open for users who wish to add another algorithm to 
# calculate the projected demand forecast based on more sophisticated extrapolation models
# See http://en.wikipedia.org/wiki/Extrapolation
# Also see techniques for Interpolation in a book of Numeric Methods
# For now, this method is used as a stub to generate random demand estimations, between 0 and 10
		return Random.new.rand(0..10)
	end
end

class EstimateByInterpolation < DemandEstimationStrategy
	def estimate_demand(logicalsvcname)
		logicalsvcid = DBAccess.new.getcolumnvalue("id", "LogicalServices", "logicalsvcname='"+logicalsvcname+"'")
		if not logicalsvcid.nil?
			dbobject = DBAccess.new
			# Obtain the x0, y0 pair : How it was two hours ago
			rows = dbobject.getrows("select "+dbobject.isnull("sum(qtyrequests)",0)+" as sumofrecords from DemandRecords where logicalsvcid = "+logicalsvcid.to_s+" and timestamp <= "+dbobject.get_date(-2,0,0)+" and timestamp>= "+dbobject.get_date(-3,0,0))
			x0 = 1
			y0 = rows[0]["sumofrecords"]
			
			# Obtain the x1, y1 pair : How it was two hours ago
			rows = dbobject.getrows("select "+dbobject.isnull("sum(qtyrequests)",0)+" as sumofrecords from DemandRecords where logicalsvcid = "+logicalsvcid.to_s+" and timestamp <= "+dbobject.get_date(-1,0,0)+" and timestamp>= "+dbobject.get_date(-2,0,0))
			x1 = 2
			y1 = rows[0]["sumofrecords"]
			
			y2 = interpolate(x0,y0,x1,y1,3)
			
			if y2 == 0
			# If there are no demand records, it is necessary to "force" it to create 1 server
				return 1
			else		
				x = y2 / @policy.max_requests_per_server
				return x.ceil
			end
		else
			return 0
		end	
	end

	def interpolate(x0, y0, x1, y1, x2)
	# Sample function obtained from http://techii.wordpress.com/2012/03/24/linear-interpolation-function-in-ruby/
	# It is Linear Interpolation
        y2 = 0
        y2 = y0.to_f + ((y1-y0).to_f*(x2-x0).to_f/(x1-x0).to_f)
        y2 = y2.ceil
        return y2
    end
end
