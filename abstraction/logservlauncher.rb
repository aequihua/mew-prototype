load './logicalservice.rb'
load '../data/dbaccessor.rb'

class LogicalSvcLauncher
attr_accessor :mewlogical
	def initialize(logservicename)
		puts 'LAUNCHING THE MEW PROTOTYPE - LOGICAL SERVICE'
		@mewlogical = LogicalService.new(logservicename,'urn:'+logservicename, 'localhost',12321)
	end
	
	def launch
		trap('INT') {@mewlogical.shutdown}  
		@mewlogical.start  	  
	end
end

# Code lines to launch automatically
x=LogicalSvcLauncher.new('memcached')
x.launch
