load './logicalservice.rb'
load './elasticitymgr.rb'
load '../data/dbaccessor.rb'

class MEWLauncher
attr_accessor :mewelasticity, :mewlogical
	def initialize(logservicename)
		puts 'LAUNCHING THE MEW PROTOTYPE - LOGICAL SERVICE'
		@mewelasticity = ElasticityManager.new('memcached')
		@mewlogical = LogicalService.new('memcached','urn:memcached', 'localhost',12321)
	end
	
	def clear_records
		db = DBAccess.new
		
		db.execnonquery('update supplierslogicalsvcs set unitsused=0')
		db.execnonquery('delete from physicalservices')
		db.execnonquery('delete from serverlog')
#		db.execnonquery('delete from demandrecords')
		db.execnonquery('delete from capacityrecords')
		
		puts 'Records cleared, statistics will begin to be generated again'
	end
	
	def launch(clearrecords=false, nrtimes=1)
		if clearrecords
			clear_records
		end
		
		@mewelasticity.activate_manager(nrtimes)
	end
end

# Code lines to launch the objects
# mewserver = LogicalService.new('memcached','urn:memcached','localhost',12321)  
# trap('INT') {mewserver.shutdown}

# Code lines to launch automatically
nrtimes = ARGV.empty? ? 1 : ARGV[0].to_i
x=MEWLauncher.new('memcached')
x.launch(true, nrtimes)

