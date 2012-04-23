require_relative '..\abstraction\cloudsvcpolicy'

class DBAccessStrategy
  def getrows(query)
  end
  
  def execnonquery(query)
  end  
  
  def getcolumnvalue(columname, tablename, condition)
  end
end

class DBAccess
	attr_accessor :strategy, :Policy

	def getrows(query)
		return @strategy.getrows(query)	
	end
	
	def execnonquery(query)
		return @strategy.execnonquery(query)	
	end
	
	def get_date(hr=0,min=0,sec=0)
		return @strategy.get_date(hr,min,sec)
	end
	
	def isnull(column, value)
		return @strategy.isnull(column,value)
	end

	def getcolumnvalue(columname, tablename, condition)
		return @strategy.getcolumnvalue(columname, tablename, condition)
	end
	
	def initialize
		@Policy = CloudSvcPolicy.new
		
		self.strategy = case @Policy.database_type
					when "sqlite" then DBAccessor_SQLite.new(@Policy.database_connection_string)
					when "mysql" then DBAccessor_MySQL.new(@Policy.database_host, @Policy.database_connection_string, @Policy.database_user, @Policy.database_pwd)
					else DBAccessor_SQLite.new(@Policy.database_connection_string)
				 end		
	end
end


class DBAccessor_SQLite < DBAccessStrategy
  attr_accessor :db, :Policy

  def initialize(dbname)
	require 'sqlite3'
	@db = SQLite3::Database.open(dbname)
	@db.results_as_hash = true
	@db.type_translation = true
	return 'ok'
  end
  
  def get_date(hr=0,min=0,sec=0)
  # Funcion que saca la fecha actual +,- cierto tiempo en formato nativo de SQLite
	return " datetime('now', '"+hr.to_s+" hour','"+min.to_s+" minute','"+sec.to_s+" second')"
  end
  
  
  def isnull(column, value)
	if value.class.name=='String'
		type="'"+value+"'"
	else
		type=value.to_s
	end
	return "ifnull("+column+","+type+")"
  end  
  
  def getcolumnvalue(columname, tablename, condition)
	puts "Reading column " + columname + " from table " + tablename + " with condition: " + condition
	query = "select " + columname + " from " + tablename + " where " + condition

	rows = @db.execute(query)

	if rows.empty?
		column = nil
	else
		firstrow = rows[0] 
		column = firstrow[columname]
	end	
	
	return column
  end
  
  def getrows(query)
	puts "Query to launch: " + query
	rows = @db.execute(query)
	return rows
  end
  
  def execnonquery(query)
	puts "NonQuery to launch: " + query
	@db.execute(query)
  end
  
end

class DBAccessor_MySQL < DBAccessStrategy
  attr_accessor :db, :Policy
  
  def get_date(hr=0,min=0,sec=0)
  # Funcion que saca la fecha actual +,- cierto tiempo en formato nativo de MySql
	return " addtime(now(),'"+hr.to_s+":"+min.to_s+":"+sec.to_s+".0')"
  end
  
  def isnull(column, value)
	if value.class.name=='String'
		type="'"+value+"'"
	else
		type=value.to_s
	end
	return "ifnull("+column+","+type+")"
  end  

  def initialize(host, dbname, user, pwd)
	require 'mysql2'
	@db = Mysql2::Client.new(:host=>host, :username=>user,:password=>pwd, :database=>dbname)
	return 'ok'
  end
  
  def getcolumnvalue(columname, tablename, condition)
	puts "Reading column " + columname + " from table " + tablename + " with condition: " + condition
	
	query = "select " + columname + " from " + tablename + " where " + condition

	rows = @db.query(query)

	if rows.entries.empty?
		column = nil
	else
		firstrow = rows.entries[0] 
		column = firstrow[columname]
	end	
	
	return column
  end
  
  def getrows(query)
	puts "Query to launch: " + query
	begin
	# Es necesario regresar un hash que tenga el nombre de campo como llave, y su valor
		rows = @db.query(query)
		return rows.entries
   rescue => e
		puts "Error processing the query, no rows fetched"
		puts e.message
		return Array.new
	end
  end
  
  def execnonquery(query)
	puts "NonQuery to launch: " + query
	begin
		@db.query(query)
	rescue => e
		puts "Error processing the non-query: " + query
		puts e.message
	ensure
		return @db.affected_rows
	end
  end
  
end

