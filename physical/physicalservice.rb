require_relative '../data/dbaccessor'
require 'uri'
require 'dalli'

class PhysicalService
	attr_accessor :physicalService, :supplierID, :serviceURI, :serviceusr, :servicepwd, :servicecost, 
					:servicedistance, :nominalcapacity, :usedcapacity, :logicalsvcID, :cache
	
	def initialize(supplierid, supplierdistance, logicalsvcid, svcname)
	# Populate the object values when the service is to be created for the first time
		@physicalService = svcname
		@supplierID = supplierid
		@servicedistance = supplierdistance
		@logicalsvcID = logicalsvcid		
		return 'ok'
	end
	
	def populate(row)
	# This method is created to allow manual population of the object, based on existing data in
	# the physical services table. Useful when recovering the circle from the database
		@physicalService = row["physicalsvcname"]
		@logicalsvcID = row["logicalsvcid"]
		@supplierID = row["supplierid"]
		@serviceURI = row["serviceURI"]
		@serviceusr = row["serviceusr"]
		@servicepwd = row["servicepwd"]
		@servicecost = row["servicecost"]
		@servicedistance = row["servicedistance"]
		@nominalcapacity = row["nominalcapacity"]
		@usedcapacity = row["usedcapacity"]	
	end
	
	def get_connect_data
		splitted = URI::parse(@serviceURI)  #The service URI must follow the standard URI convention!!
		return splitted  #Return the hostname and the port, among other elements. It is a hash
	end

    def open_connection
		connstr = get_connect_data.host+":"+get_connect_data.port.to_s
		puts "connecting to "+connstr
		@cache = Dalli::Client.new(connstr)
		puts @cache
	end
	
	def get(pkey)
	   open_connection
	   val = @cache.get(pkey)
	   puts val
	   return val
	end
 
	def set(pkey, value)
	   open_connection
	   result = @cache.set(pkey,value)
		value = "Resultado real de SET, respondio " + @physicalService + " URI = " + @serviceURI
	end

	def registerintable
		rows = DBAccess.new.getrows("select * from SuppliersLogicalSvcs where logicalsvcid=" + @logicalsvcID.to_s + " and supplierid=" + @supplierID.to_s)
		if not rows.empty?
			@serviceURI = rows[0]["baseserviceURI"]
			@servicecost = rows[0]["baseservicecost"]
			@nominalcapacity = rows[0]["baseservicecapacity"]
			@usedcapacity = 0
			@serviceusr = rows[0]["baseserviceusr"]
			@servicepwd = rows[0]["baseservicepwd"]

			# Insert in the PhysicalServices table, for which we need to get the Supplier information first
			DBAccess.new.execnonquery("insert into physicalservices (logicalsvcid, physicalsvcname, supplierid, serviceURI, serviceusr, servicepwd, servicecost, servicedistance, nominalcapacity, usedcapacity) values ("+@logicalsvcID.to_s+",'"+@physicalService+"',"+@supplierID.to_s+",'"+@serviceURI+"','"+@serviceusr+"','"+@servicepwd+"',"+@servicecost.to_s+","+@servicedistance.to_s+","+@nominalcapacity.to_s+","+@usedcapacity.to_s+")")
		else
			@serviceURI = ""
			@servicecost = 0
			@servicedistance = 9999
			@nominalcapacity = 0
			@usedcapacity = 0
			@serviceusr = ""
			@servicepwd = ""
		end
	end
	
	
	def deletefromtable
	# Delete the entry from physical services and release the capacity in the SupplierLogicalSvcs table
		dbobject = DBAccess.new
		
		dbobject.execnonquery("update supplierslogicalsvcs set unitsused=unitsused-1 where logicalsvcid = " + @logicalsvcID.to_s+" and supplierid="+@supplierID.to_s)
		
		dbobject.execnonquery("delete from physicalservices where logicalsvcid = " + @logicalsvcID.to_s+" and supplierid="+@supplierID.to_s+" and physicalsvcname='"+ @physicalService+"'")
	end
	
	def start_service
		registerintable
	end

	def stop_service
		deletefromtable
	end
				
end

class InternalService < PhysicalService
	def get(pkey)
	   puts "Simulado de GET interno"	   	
	   value = "Resultado simulado de GET INTERNO, respondio " + @physicalService + " URI = " + @serviceURI
	   return 10
	end

	def set(pkey, value)
	   puts "Resultado simulado de SET INTERNO,  respondio " + (pkey.nil? ? "Nulo" : pkey) + ":" + @physicalService + " URI = " + @serviceURI
	   return 0
	end

	def start_service
		registerintable
		
		# PONER AQUI EL CODIGO QUE LEVANTA EL SERVICIO FISICAMENTE
		puts "Simulado de arranque de servicio fisico interno"
	end

	def stop_service
		deletefromtable
		
		# PONER AQUI EL CODIGO QUE TUMBA EL SERVICIO FISICAMENTE
		puts "Simulado de paro de servicio fisico interno"	
	end
end

class ExternalService < PhysicalService
	def get(pkey)
	   puts "Simulado de GET externo"	   
	   value = "Resultado simulado de GET EXTERNO, respondio " + @physicalService + " URI = " + @serviceURI
	   return 10
	end

	def set(pkey, value)
	   puts "Resultado simulado de SET EXTERNO, respondio " + (pkey.nil? ? "Nulo" : pkey) + " :  " + @physicalService + " URI = " + @serviceURI
	   return 0
	end

	def start_service
		registerintable
		
		# PONER AQUI EL CODIGO QUE LEVANTA EL SERVICIO FISICAMENTE		
		puts "Arranque de servicio fisico externo"
		puts @cache
	end

	def stop_service
		deletefromtable
		
		# PONER AQUI EL CODIGO QUE TUMBA EL SERVICIO FISICAMENTE		
		puts "Simulado de paro de servicio fisico externo"
	end
end

class PhysServiceCreator
	attr_accessor :supplierid, :supplierdistance, :logicalsvcID
	
	def initialize(supplierid, supplierdistance, logicalsvcID)
	# The physical service factory will create services for one specific supplier
		@supplierid = supplierid
		@supplierdistance = supplierdistance
		@logicalsvcID = logicalsvcID		
	end
	
	def create(serviceName)
		raise NotImplementedError, "This type of factory is not implemented! "	
	end
	
	def getsequencer
		dbobject = DBAccess.new
	# Are there available units from this supplier? if yes, consume one more, update the table and create the physical service
		rows = dbobject.getrows("select * from SuppliersLogicalSvcs where logicalsvcid=" + @logicalsvcID.to_s + " and supplierid=" + @supplierid.to_s + " and unitscapacity>unitsused")
		if rows.empty?
			return 0
		else
		# Update the table so that the capacity is locked properly
			dbobject.execnonquery("update SuppliersLogicalSvcs set unitsused = unitsused + 1  where ID =" + rows[0]["id"].to_s)
			sequence = dbobject.getcolumnvalue("max(id)+1","physicalservices","1=1")
			if sequence.nil? 
				return 1
			else
				return sequence
			end
		end
	end
end

class InternalSvcCreator < PhysServiceCreator
	def create(serviceName)	
	  sequence = getsequencer
	  if sequence>0
		 return  InternalService.new(@supplierid, @supplierdistance, @logicalsvcID, serviceName + "_" + sequence.to_s)	
	  else
		 return nil
	  end
	end
end

class ExternalSvcCreator < PhysServiceCreator
	def create(serviceName)
		sequence = getsequencer
	    if sequence > 0
			return ExternalService.new(@supplierid, @supplierdistance, @logicalsvcID, serviceName + "_" + sequence.to_s)	
		else
			return nil
		end
	end
end
