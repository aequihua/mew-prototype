require 'dalli'

cache = Dalli::Client.new('localhost:11211')
puts "\n\n== Demostracion simple de memcached ==\n\n"
puts "Estoy almacenando una tupla (Llave,Valor)"
cache.set("Llave","Valor")
puts "Estoy obteniendo el valor a partir de la Llave: " + cache.get("Llave")


# WEB SERVICE INVOKER
# require 'soap/rpc/driver'  
# puts "Demo de llamado por web service"
# driver = SOAP::RPC::Driver.new('http://127.0.0.1:12321/', 'urn:memcached')  
# driver.add_method('mset', 'tenantid', 'pkey', 'value')  
# driver.add_method('mget', 'tenantid', 'pkey')  
# puts driver.mset(1,"Llave2","Valor2")
# puts driver.mget(1,"Llave2")


require_relative '../client/ServiceClient'

cache = ServiceClient.new
puts "\n\n== Demostracion simple de memcached CON LA NUBE ==\n\n"
puts "Estoy almacenando una tupla (Llave,Valor)"
cache.set("Llave","Valor")
puts "Estoy obteniendo el valor a partir de la Llave: " + cache.get("Llave")
