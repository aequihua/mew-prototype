
create table Tenants
( id integer primary key autoincrement,
  tenantname varchar(40) null,
  tenantversion varchar(10) null,
  language varchar(20) null);
  
create table TenantLogicalSvcs
(
	tenantid integer null,
	logicalsvcid integer null,
	foreign key (tenantid) references Tenants(ID),
	foreign key (logicalsvcid) references LogicalServices(ID)
);

create table LogicalServices
(  id integer primary key autoincrement,
  logicalsvcname varchar(30) null,
  logicalsvcdescription varchar(40) null,
  version varchar(10) null);
  
create table CapacityRecords
( id integer primary key autoincrement,
  timestamp integer null,
  logicalsvcid integer null,
  capacity integer null,
  message varchar(80) null,
  foreign key(logicalsvcid) references LogicalServices(id));  

create table DemandRecords
( id integer primary key autoincrement,
  timestamp integer null,
  logicalsvcid integer null,
  tenantid integer null,
  qtyrequests integer null,
  sizerequests integer null,
  message varchar(80) null,
  foreign key(logicalsvcid) references LogicalServices(id),
  foreign key(tenantid) references Tenants(id));  
  
create table PhysicalServices
 (id integer primary key autoincrement,
  logicalsvcid integer null,
  physicalsvcname varchar(20) null,
  supplierid integer null,
  serviceURI varchar(100) null,
  serviceusr varchar(20) null,
  servicepwd varchar(20) null,
  servicecost real null,
  servicedistance integer null,
  nominalcapacity integer null,
  usedcapacity integer null,
  foreign key(logicalsvcid) references LogicalServices(id),
  foreign key(supplierid) references ServiceSuppliers(id)); 
 
create table ServerLog
( id integer primary key autoincrement,
  timestamp integer null,
  physvcid integer null,
  eventtype varchar(20) null,
  message varchar(80) null,
  foreign key(physvcid) references PhysicalServices(id));  
  
create table ServiceSuppliers
( id integer primary key autoincrement,
  suppliername varchar(30) null,
  suppliertype varchar(10) null,
  userid varchar(20) null,
  userpwd varchar(20) null,
  supplierURI varchar(100) null,
  suppliercost real null,
  supplierdistance integer null
);  

create table SuppliersLogicalSvcs
(  id integer primary key autoincrement,
   logicalsvcid integer null,
   supplierid integer null,
   unitscapacity integer null,
   unitsused integer null,
   baseservicecost real null,
   baseserviceURI varchar(100) null,
   baseserviceusr varchar(20) null,
   baseservicepwd varchar(20) null,
   baseservicecapacity integer null,
   foreign key(logicalsvcid) references LogicalServices(id),
   foreign key(supplierid) references ServiceSuppliers(id)
);
   

insert into Tenants values (1, 'Tenant 01', '1.0', 'Node.js');
insert into Tenants values (2, 'Tenant 02', '2.0', 'Ruby');
insert into Tenants values (3, 'Tenant 03', '3.0', 'Java');
insert into Tenants values (4, 'Tenant 04', '3.0', 'Java');
insert into Tenants values (5, 'Tenant 05', '3.0', 'Java');
insert into Tenants values (6, 'Tenant 06', '3.0', 'Java');
insert into Tenants values (7, 'Tenant 07', '3.0', 'Java');
insert into Tenants values (8, 'Tenant 08', '3.0', 'Java');
insert into Tenants values (9, 'Tenant 09', '3.0', 'Java');
insert into Tenants values (10, 'Tenant 10', '3.0', 'Java');

insert into LogicalServices values (1, 'memcached', 'Key-value store service', '3.3');
insert into LogicalServices values (2, 'stub', 'Custom primary-key service', '1.0');

insert into ServiceSuppliers values (1,'Private cloud','Internal','root','root','anyhost:4000',0,0);
insert into ServiceSuppliers values (2,'Amazon Web Services','External','root','root','anyhost:4000',100,2);
insert into ServiceSuppliers values (3,'HP Labs','External','root','root','anyhost:4000',80,3);

insert into SuppliersLogicalSvcs values (1,1,1,1,0,100,"something:1000","user","pwd",10);
insert into SuppliersLogicalSvcs values (2,1,2,1,0,200,"something:1000","user","pwd",10);
insert into SuppliersLogicalSvcs values (3,1,3,1,0,300,"something:1000","user","pwd",10);
insert into SuppliersLogicalSvcs values (4,2,1,1,0,100,"something:1000","user","pwd",10);
insert into SuppliersLogicalSvcs values (5,2,2,1,0,200,"something:1000","user","pwd",10);
insert into SuppliersLogicalSvcs values (6,2,3,1,0,300,"something:1000","user","pwd",10);
