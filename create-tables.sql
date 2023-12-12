


drop table test_objects cascade constraints purge;

drop table xp_object_id cascade constraints purge; 

drop table xp_object_names cascade constraints purge; 

drop table xp_object_dates cascade constraints purge; 

drop table xp_object_types cascade constraints purge;

drop table xp_object_status cascade constraints purge;

commit;


prompt TEST_OBJECTS

create table test_objects
as 
select * from all_objects
where subobject_name is null
/


prompt XP_OBJECT_ID

create table xp_object_id as 
select owner, object_id
from test_objects
/

prompt XP_OBJECT_NAMES

create table xp_object_names as
select owner, object_id, object_name
from test_objects
/

prompt XP_OBJECT_DATES

create table xp_object_dates as 
select owner, object_id, created, last_ddl_time, timestamp
from test_objects
/

prompt XP_OBJECT_TYPES

create table xp_object_types as
select owner, object_id, object_type
from test_objects
/

prompt XP_OBJECT_STATUS

create table xp_object_status as
select owner, object_id, status, temporary, generated
from test_objects
/

commit;


