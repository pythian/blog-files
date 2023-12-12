
-- these views are contrived, but suitable for demonstration purposes

PROMPT XP_OBJECT_ID_V

create or replace view xp_object_id_v as select * from xp_object_id;

PROMPT XP_OBJECT_DATES_V

create or replace view xp_object_dates_v as select * from  xp_object_dates;

--
PROMPT XP_OBJECT_NAMES_V

create or replace view xp_object_names_v as select * from  xp_object_names;

--
PROMPT XP_OBJECT_TYPES_V

create or replace view xp_object_types_v as select * from xp_object_types;

--
PROMPT XP_OBJECT_STATUS_V

create or replace view xp_object_status_v as select * from xp_object_status;

------------------------------

PROMPT XP_OBJECT_ID_TYPE_V

create or replace view xp_object_id_type_v as
select 
	o.owner
	, o.object_id
	, t.object_type
from xp_object_id_v o
join xp_object_types_v t on t.object_id = o.object_id
/

PROMPT XP_OBJECT_ID_NAME_V

create or replace view xp_object_id_name_v as
select 
	o.owner
	, o.object_id
	, n.object_name
from xp_object_id_v o
join xp_object_names_v n on n.object_id = o.object_id
/

PROMPT XP_OBJECT_ID_STATUS_V

create or replace view xp_object_id_status_v as
select 
	o.owner
	, o.object_id
	, s.status
	, s.temporary
	, s.generated
from xp_object_id_v o
join xp_object_status_v s
on s.object_id = o.object_id
/

PROMPT XP_OBJECT_ID_DATES_V

create or replace view xp_object_id_dates_v as
select 
	o.owner
	, o.object_id
	, s.created
	, s.last_ddl_time
	, s.timestamp
from xp_object_id_v o
join xp_object_dates_v s
on s.object_id = o.object_id
/

--------------------- 

PROMPT XP_OBJECTS_V

create or replace view xp_objects_v
as
select
	t.owner
	, t.object_id
	, t.object_type
	, n.object_name
	, s.status
	, d.created
	, d.last_ddl_time
from  xp_object_id_type_v t
join xp_object_id_name_v n on n.object_id = t.object_id
join xp_object_id_status_v s on s.object_id = t.object_id
join xp_object_id_dates_v d on d.object_id = t.object_id
/




