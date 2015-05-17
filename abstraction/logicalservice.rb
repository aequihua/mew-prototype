require_relative '../data/dbaccessor'
require_relative './multitenancymgr'
require 'rubygems'
gem 'soap4r'
require 'soap/rpc/standaloneServer'  
require_relative './tenant'

# The logical service is defined as a SOAP server
# To make it callable from other platforms as long as they support SOAP

class Service < SOAP::RPC::StandaloneServer
	def initialize(*args)
		super
	end
	
	def set(tenantID, primaryKey, value)
	end

	def get(tenantID, primaryKey)
	end
end

class LogicalService < Service
	attr_accessor :bIsValid, :logicalsvcname, :logicalsvcid, :subject, :MM
	
	def initialize(*args)
	  # Call the superclass in order to initialize the SOAP environment
	   super
	   @logicalsvcname = args[0]
	  # Declare the exposed methods in the SOAP server
	   add_method(self, 'mset', 'tenantID', 'primaryKey', 'value')
	   add_method(self, 'mget', 'tenantID', 'primaryKey')
	end
			
	def mset(tenantID, primaryKey, value)
		service  = LogicalServiceProxy.new(@logicalsvcname, RealLogicalService.new(@logicalsvcname), tenantID)
		if not service.nil? and service.bIsValid
			service.realset(tenantID, primaryKey, value)
		else
			service = nil
			record_log("Set call not made, invalid authentication")
		end
	end
	
	def mget(tenantID, primaryKey)
		service  = LogicalServiceProxy.new(@logicalsvcname, RealLogicalService.new(@logicalsvcname), tenantID)
		if not service.nil? and service.bIsValid
			value = service.realget(tenantID, primaryKey)
		else
			value = nil
			service = nil
			record_log("Invalid GET, user not authenticated properly")
		end
		return value
	end
	
	def record_log(msg)
		puts msg
	end
	
end

class LogicalServiceProxy < LogicalService
  def initialize(logicalsvcname, realSubject, tenantID)
	  @logicalsvcname = logicalsvcname
      @subject = realSubject
	  @logicalsvcid = DBAccess.new.getcolumnvalue("id", "LogicalServices", "logicalsvcname='"+@logicalsvcname+"'")

      if tenantID.nil? or @logicalsvcid.nil? or not tenantRegistered?(tenantID)   # Check if the string has certain length, certain sequence, etc
          @bIsValid  = false
      else	  
	  # Register the Tenant to the logical service
		  DBAccess.new.execnonquery("insert into TenantLogicalSvcs (tenantid, logicalsvcid) values ("+tenantID.to_s+","+@logicalsvcid.to_s+")")
		  @bIsValid  = true
      end
  end
  
  def start_service()
  end
  
  def stop_service()
  end
  
  def tenantRegistered?(tenantID)
	 result = Tenant.new.exists?(tenantID)
	 record_log("Tenant exists = " + result.to_s)
	 return result
  end
  
  def method_missing(name, *args)
      record_log( "Delegating #{name} message to subject.")

      if (@subject.respond_to?(name)) and @bIsValid    # Validate if the method exists in the real object
            result = @subject.send(name, *args)
            record_log("Made a call to method name: " + name.to_s)
			return result
      else
            record_log("Invalid method name : " + name.to_s)
			return 0
      end
  end  
  
end

class RealLogicalService < LogicalService
	require 'digest/md5'
	
	attr_accessor :result
	
	def initialize(logicalsvcname)
		@logicalsvcname = logicalsvcname
		@result = nil
		@MM = MultitenancyManager.new(@logicalsvcname)  # Obtain the multitenancy manager that will respond					
	end
	
	def put_status_message(obj, pkey, method)
		if not obj.nil?
			puts obj
			 record_log("Service call successful : " + method.to_s  + "," + pkey)
			 "success"
		else
			 record_log("Service call was not made successfully : " + method.to_s)
			 "failed"
		end
	end
	
	def call_method(primaryKey, tenantID)
	# This is the actual method caller, that does logic to select the physical server
	# And call the physical service, by doing embedded code (the yield statement)
		@result = nil
		
		yield		
	end
		
	def realset(tenantID, primaryKey, value)
		call_method(primaryKey, tenantID) { |physicalKey,servObject|
			size = Memory.analyze(primaryKey).bytes + Memory.analyze(value).bytes
			servObject, physicalKey = @MM.get_physical_service(primaryKey, size, tenantID)
			if not servObject.nil?
				servObject.set(physicalKey, value)
			end
			put_status_message(servObject,physicalKey, __method__)
		}		
		puts @result
		return @result
	end

	def realget(tenantID, primaryKey)
		call_method(primaryKey, tenantID) {  |physicalKey,servObject|
			size = Memory.analyze(primaryKey).bytes
			servObject, physicalKey = @MM.get_physical_service(primaryKey, size, tenantID)
			put_status_message(servObject,physicalKey, __method__)
			if not servObject.nil?
				@result = servObject.get(physicalKey)
			end
		}
		return @result		
	end	
end

module Memory
  # sizes are guessed, I was too lazy to look
  # them up and then they are also platform
  # dependent
  REF_SIZE = 4 # ?
  OBJ_OVERHEAD = 4 # ?
  FIXNUM_SIZE = 4 # ?

  # informational output from analysis
  MemoryInfo = Struct.new :roots, :objects, :bytes, :loops

  def self.analyze(*roots)
    an = Analyzer.new
    an.roots = roots
    an.analyze
  end

  class Analyzer
    attr_accessor :roots
    attr_reader   :result

    def analyze
      @result = MemoryInfo.new roots, 0, 0, 0
      @objs = {}

      queue = roots.dup

      until queue.empty?
        obj = queue.shift

        case obj
        # special treatment for some types
        # some are certainly missing from this
        when IO
          visit(obj)
        when String
          visit(obj) { @result.bytes += obj.size }
        when Fixnum
          @result.bytes += FIXNUM_SIZE
        when Array
          visit(obj) do
            @result.bytes += obj.size * REF_SIZE
            queue.concat(obj)
          end
        when Hash
          visit(obj) do
            @result.bytes += obj.size * REF_SIZE * 2
            obj.each {|k,v| queue.push(k).push(v)}
          end
        when Enumerable
          visit(obj) do
            obj.each do |o|
              @result.bytes += REF_SIZE
              queue.push(o)
            end
          end
        else
          visit(obj) do
            obj.instance_variables.each do |var|
              @result.bytes += REF_SIZE
              queue.push(obj.instance_variable_get(var))
            end
          end
        end
      end

      @result
    end

  private
    def visit(obj)
      id = obj.object_id

      if @objs.has_key? id
        @result.loops += 1
        false
      else
        @objs[id] = true
        @result.bytes += OBJ_OVERHEAD
        @result.objects += 1
        yield obj if block_given?
        true
      end
    end
  end
end
