
set serveroutput on format wrapped size unlimited

def max_baseline_len=30
def snapshot_flush_mode='ALL'

declare
	type t_snap_tab_typ is table of pls_integer index by varchar2(10);
	t_snap_tab t_snap_tab_typ;
	key varchar2(10);
	i_expire_days pls_integer := 21;
	v_baseline_name varchar2(&max_baseline_len);  -- max size of baseline name, contrary to docs
	i_baseline_exists pls_integer := 0;
begin

	-- just a prototype for creating two snapshots and a self expiring baseline
	-- format is TAG-DB_SESSIONS-CLIENT_CONNECTIONS
	v_baseline_name := 'SQLRUN-20-200';

	select count(*) into i_baseline_exists
	from dba_hist_baseline
	where baseline_name = v_baseline_name;

	if i_baseline_exists > 0 then
		raise_application_error(-20000,'Baseline ' || v_baseline_name || ' already exists');
	end if;

	-- the baseline could be created on start/end times
	-- doing it this way though gets the 'ALL' mode snapshot, with more info
	-- as this is a testing environment, it is not important if a snapshot takes several seconds to complete
	-- create first snapshot
	t_snap_tab('begin') := dbms_workload_repository.create_snapshot('&snapshot_flush_mode');

	-- sleep a bit
	dbms_lock.sleep(15);

	t_snap_tab('end') := dbms_workload_repository.create_snapshot('&snapshot_flush_mode');

	dbms_workload_repository.create_baseline(
		start_snap_id => t_snap_tab('begin'),
		end_snap_id => t_snap_tab('end'),
		baseline_name => v_baseline_name,
		expiration => i_expire_days
	);
	

	dbms_output.put_line('baseline: ' || v_baseline_name);
	dbms_output.put_line('begin: ' || t_snap_tab('begin'));
	dbms_output.put_line('  end: ' || t_snap_tab('end'));

end;
/


