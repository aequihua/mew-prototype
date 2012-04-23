---  Scripts to create the database for the Multitenancy-Elasticity wrapper
---  MySQL syntax
---  Author:  Arturo Equihua
---- Date : April 20th, 2012

SET FOREIGN_KEY_CHECKS=0;

 
DROP DATABASE if exists mewdev;

 
CREATE DATABASE mewdev
  CHARACTER SET utf8
  COLLATE utf8_general_ci;

 
USE mewdev;

drop table if exists Tenants;
create table Tenants
( id integer primary key auto_increment,
  tenantname varchar(40) null,
  tenantversion varchar(10) null,
  language varchar(20) null);
  
drop table if exists TenantLogicalSvcs;
create table TenantLogicalSvcs
(
	tenantid integer null,
	logicalsvcid integer null
);

drop table if exists LogicalServices;
create table LogicalServices
(  id integer primary key auto_increment,
  logicalsvcname varchar(30) null,
  logicalsvcdescription varchar(40) null,
  version varchar(10) null);
  
drop table if exists CapacityRecords;
create table CapacityRecords
( id integer primary key auto_increment,
  timestamp datetime null,
  logicalsvcid integer null,
  capacity integer null,
  message varchar(200) null);  
  
drop table if exists DemandRecords;
create table DemandRecords
( id integer primary key auto_increment,
  timestamp datetime null,
  logicalsvcid integer null,
  tenantid integer null,
  primarykey varchar(200) null,
  physicalkey varchar(200) null,
  resolver varchar(20) null,
  qtyrequests integer null,
  sizerequests integer null,
  message varchar(200) null);  
  
drop table if exists PhysicalServices;
create table PhysicalServices
 (id integer primary key auto_increment,
  logicalsvcid integer null,
  physicalsvcname varchar(20) null,
  supplierid integer null,
  serviceURI varchar(100) null,
  serviceusr varchar(20) null,
  servicepwd varchar(20) null,
  servicecost real null,
  servicedistance integer null,
  nominalcapacity integer null,
  usedcapacity integer null); 

  
drop table if exists ServerLog;
create table ServerLog
( id integer primary key auto_increment,
  timestamp datetime null,
  physvcid integer null,
  eventtype varchar(20) null,
  message varchar(200) null);  
    
drop table if exists ServiceSuppliers;
create table ServiceSuppliers
( id integer primary key auto_increment,
  suppliername varchar(30) null,
  suppliertype varchar(10) null,
  userid varchar(20) null,
  userpwd varchar(20) null,
  supplierURI varchar(100) null,
  suppliercost real null,
  supplierdistance integer null
);  

drop table if exists SuppliersLogicalSvcs;
create table SuppliersLogicalSvcs
(  id integer primary key auto_increment,
   logicalsvcid integer null,
   supplierid integer null,
   unitscapacity integer null,
   unitsused integer null,
   baseservicecost real null,
   baseserviceURI varchar(100) null,
   baseserviceusr varchar(20) null,
   baseservicepwd varchar(20) null,
   baseservicecapacity integer null
);
 
 
 ---- Foreign key constraints
 
alter table TenantLogicalSvcs
add constraint TenantLogicalSvcs01
foreign key (tenantid) references Tenants(ID)
on delete no action 
on update no action;

alter table TenantLogicalSvcs
add constraint TenantLogicalSvcs02
foreign key (logicalsvcid) references LogicalServices(ID)
on delete no action 
on update no action;

alter table CapacityRecords
add constraint CapacityRecords01
foreign key(logicalsvcid) references LogicalServices(id)
on delete no action 
on update no action;

alter table DemandRecords
add constraint DemandRecords01
foreign key(logicalsvcid) references LogicalServices(id)
on delete no action 
on update no action;

alter table DemandRecords
add constraint DemandRecords02
foreign key(tenantid) references Tenants(id)
on delete no action 
on update no action;

alter table PhysicalServices
add constraint PhysicalServices01
foreign key(logicalsvcid) references LogicalServices(id)
on delete no action 
on update no action;

alter table PhysicalServices
add constraint PhysicalServices02
foreign key(supplierid) references ServiceSuppliers(id)
on delete no action 
on update no action;

alter table SuppliersLogicalSvcs
add constraint SuppliersLogicalSvcs01
foreign key(logicalsvcid) references LogicalServices(id)
on delete no action 
on update no action;

alter table SuppliersLogicalSvcs
add constraint SuppliersLogicalSvcs02
foreign key(supplierid) references ServiceSuppliers(id)
on delete no action 
on update no action;

----  Demo dataset

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

insert into SuppliersLogicalSvcs values (1,1,1,1,0,100,"memcached://localhost:11211","user","pwd",10);
insert into SuppliersLogicalSvcs values (2,1,2,1,0,200,"memcached://ec2-184-72-152-41.compute-1.amazonaws.com:11211","user","pwd",10);
insert into SuppliersLogicalSvcs values (4,2,1,3,0,100,"something:1000","user","pwd",10);
insert into SuppliersLogicalSvcs values (5,2,2,1,0,200,"something:1000","user","pwd",10);
insert into SuppliersLogicalSvcs values (6,2,3,2,0,300,"something:1000","user","pwd",10);
