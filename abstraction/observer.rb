require 'date'
require_relative '../data/dbaccessor'
require 'logger'
require_relative './cloudsvcpolicy'

WARN = 'WARN'
DEBUG = 'DEBUG'
ERROR = 'ERROR'
INFO = 'INFO'
FATAL = 'FATAL'

class Observer
	attr_accessor :logFileName, :eventcounter, :policy
	
	def initialize(fname)
		@logFileName = './generic.log'
		@logFileName = './' + fname + '.log' if not fname.nil?
		@eventcounter = 0
		@policy = CloudSvcPolicy.new		
		return 'ok'
	end

	def writeLog(msg)
	   if not File.exist?(@logFileName)
			resetFile()
	   end if

	   file = File.open(@logFileName, 'a')
	   file.puts( getTimeStamp + " " + msg)
	   @eventcounter = @eventcounter + 1
	end
	
	def updateSubject
	end
	
	def resetFile
		file = File.open(@logFileName,'w')   # Crear el archivo nuevo    	
	end
	
	def getTimeStamp
		n = Time.now
		return n.to_s
	end
end

# File-based logging
class PlainLogger < Observer
	attr_accessor :log, :loglist
	
	def initialize(logfilename)
		@eventcounter = 0
		@policy = CloudSvcPolicy.new		
		@log = Logger.new(logfilename.nil? ? './generic.log' : logfilename)
		@log.level = case @policy.verbose
			when WARN  then Logger::WARN
			when DEBUG  then Logger::DEBUG
			when ERROR  then Logger::ERROR
			when INFO  then Logger::INFO
			when FATAL  then Logger::FATAL
			else Logger::ERROR
		end
		@loglist = case @policy.verbose
			when WARN then [WARN,ERROR,FATAL]
			when DEBUG then [WARN,ERROR,FATAL,DEBUG,INFO]
			when ERROR then [ERROR,FATAL]
			when INFO then [WARN,ERROR,FATAL,INFO]
			when FATAL then [FATAL]
			else []
		end
		
		@log.info("Log started on " + getTimeStamp)
	end
	
	def updateSubject(errlevel, subject, msg)
		result = case errlevel
			when WARN then @log.warn("[" + subject + "]" + getTimeStamp + " | " + errlevel + " | " + msg)
			when DEBUG then @log.debug("[" + subject + "]" + getTimeStamp + " | " + errlevel + " | " + msg)
			when ERROR then @log.error("[" + subject + "]" + getTimeStamp + " | " + errlevel + " | " + msg)
			when INFO then @log.info("[" + subject + "]" + getTimeStamp + " | " + errlevel + " | " + msg)
			when FATAL then @log.fatal("[" + subject + "]" + getTimeStamp + " | " + errlevel + " | " + msg)
			else @log.info("[" + subject + "]" + getTimeStamp + " | " + errlevel + " | " + msg)
		end
	end
end

# Screen message display
class ScreenLogger < Observer	
	def initialize
	end
	
	def updateSubject(errlevel, subject, msg)
		fullmsg =  "[" + subject + "]" + getTimeStamp + " | " + errlevel + " | " + msg 
		puts fullmsg
	end
end

class CapacityRecorder < Observer
	def updateSubject (subject, capacity, msg)
	   fullmsg =  "[" + subject  + "]Capacity recording is " + capacity.to_s + " transactions, status message: " + msg
	   
	   dbobject = DBAccess.new
	   
	   logicalsvcid = dbobject.getcolumnvalue("id", "LogicalServices", "logicalsvcname='"+subject+"'")
	   
	   if not logicalsvcid.nil?	   	   
			status = dbobject.execnonquery("insert into CapacityRecords (timestamp, logicalsvcid, capacity, message) values ("+dbobject.get_date+", '" + logicalsvcid.to_s + "'," + capacity.to_s + ",'" + msg + "')")    # Write the observed capacity into the database
	   else
			puts "Logical service ID is not registered for : " + subject
	   end
	   
	   writeLog(fullmsg)   # Write the capacity event into a log	
	end

end

class DemandRecorder < Observer
	def updateSubject (subject, tenantID, primaryKey, physicalKey, resolver, qtyrequests, sizerequests, msg)		
	   fullmsg =  "[" + subject  + "] Demand recording is " + qtyrequests.to_s + " requests of " + sizerequests.to_s + " bytes in average, status message: " + msg
	   
	   dbobject = DBAccess.new
	   
	   logicalsvcid = dbobject.getcolumnvalue("id", "LogicalServices", "logicalsvcname='"+subject+"'")
	   
	   if not logicalsvcid.nil?	   
			status = dbobject.execnonquery("insert into DemandRecords (timestamp, logicalsvcid, tenantID, primarykey, physicalkey, resolver, qtyrequests, sizerequests, message) values ("+dbobject.get_date+", " + logicalsvcid.to_s + "," +  tenantID.to_s + ",'" + primaryKey + "','" + physicalKey + "','" + resolver + "'," + qtyrequests.to_s + "," + sizerequests.to_s + ",'" + msg + "')")    # Write the observed capacity into the database
	   else
			puts "Logical service ID is not registered for : " + subject
	   end

	   writeLog(fullmsg)   # Write the demand event into a log	
	end

end

class ServerLog < Observer
	def updateSubject (subject, eventType, msg)
	   fullmsg =  "[" + subject + "] Event type " + eventType.to_s + ", status message: " + msg
	   
	   dbobject = DBAccess.new
	   
	   physsvcid = dbobject.getcolumnvalue("id", "PhysicalServices", "physicalsvcname='"+subject+"'")
	   	   
	   if not physsvcid.nil?
			status = dbobject.execnonquery("insert into ServerLog  (timestamp, physvcid, eventtype, message) values ("+dbobject.get_date+", " + physsvcid.to_s  + ",'" + eventType.to_s + "','" + msg + "')")    # Write the event into the database
	   else
			puts "Physical service ID is not registered for : " + subject
	   end

	   writeLog(fullmsg)   # Write the demand event into a log	
	end

end
