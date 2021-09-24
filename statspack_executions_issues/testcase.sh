#!/bin/bash
. oraenv <<< CDB2

rm testcase.log

qtext="select /*"$(date)"*/  max(t_1.object_id) from t1 t_1"

sqlplus -s 'c##u1/oracle' << EOF
set lin 500 pagesize 9999 tab off trimspool on arraysize 5000
spool testcase.log
drop table t1 purge;
create table t1 as select o1.* from dba_objects o1,  dba_objects o2 where rownum <= 100000;

$(echo "$qtext;")

prompt ** Test run using this query text and SQL_ID:**
col sql_id new_value sql_id
select sql_id, sql_fulltext from v\$sql where sql_text = '$qtext' and rownum = 1;

begin
for rec in (select sql_id from DBA_HIST_COLORED_SQL)  
loop
  DBMS_WORKLOAD_REPOSITORY.REMOVE_COLORED_SQL(sql_id=>rec.sql_id);
end loop;
end;
/

exec dbms_workload_repository.add_colored_sql('&&sql_id');

select * from DBA_HIST_COLORED_SQL;

alter system flush shared_pool;

prompt ** Creating first AWR and Statspack snapshot: **
select dbms_workload_repository.create_snapshot from dual;

set lin 500 pagesize 0 tab off verify off serveroutput on trimspool on

declare x number;
begin
  x:=statspack.snap;
  dbms_output.put_line('Statspack snap created: ' || to_char(x));
end;
/

prompt ** Creating child cursors: **

SET TERMOUT OFF
declare
  n number;  
  k number;  
begin
    for i in 1..200 loop
        execute immediate 'alter session set optimizer_index_cost_adj=' || to_char(i);
        for j in 1..100 loop
		  execute immediate '$(echo "$qtext")' into n;
		  k := k + n;
		end loop;  
    end loop;
	dbms_output.put_line(k);
end;
/


SET TERMOUT ON


prompt ** Test run using this SQL_ID: **
set pagesize 1000
col sql_id new_value sql_id
select sql_id from v\$sql where sql_text = '$qtext' and rownum = 1;

prompt ** Child cursor status from v\$sql: **
select child_number, executions from v\$sql where sql_id = '&&sql_id' order by child_number;

col cnt new_value cnt
select count(*) cnt,sum(executions) from v\$sql where sql_id = '&&sql_id';


prompt ** Creating second AWR and Statspack snapshot: **

select dbms_workload_repository.create_snapshot from dual;

declare x number;
begin
  x:=statspack.snap;
  dbms_output.put_line('Statspack snap created: ' || to_char(x));
end;
/

prompt ** Perform some hard parsing in order to put pressure on the library cache: **


-- alter session set plsql_optimize_level = 0;

declare
    x number;
    y varchar2(128);
    k number;
    c number := 0;
    x1 number;
begin

k := to_number('&&cnt');
while k >= to_number(&&cnt)
loop
    y := 'select count(*) from dual where rownum = '||to_char(dbms_random.random);
    execute immediate y into x;
    x1:=x1+x;
    execute immediate y into x;
    x1:=x1+x;
    execute immediate y into x;
    x1:=x1+x;
    execute immediate y into x;
    x1:=x1+x;

    select count(*) c into k from v\$sql where sql_id = '&&sql_id';
    c:= c+1;

/*  if mod(c,10000) = 0 then
     dbms_lock.sleep(1);
    end if;
*/
end loop;
dbms_output.put_line('Number of iterations = ' || to_char(c));
dbms_output.put_line('x = ' || to_char(x));
end;
/

exec dbms_lock.sleep(30);

prompt ** Child cursor status from v\$sql after the number of child cursors decreased: **
select count(*),sum(executions) from v\$sql where sql_id = '&&sql_id';

prompt ** Execute SQL with optimizer_index_cost_adj=1000: **
alter session set optimizer_index_cost_adj=1000;
$(echo "$qtext;")

prompt ** Child cursor status from v\$sql: **
select count(*),sum(executions) from v\$sql where sql_id = '&&sql_id';


prompt **  Creating third AWR and Statspack snapshot: **
declare x number;
begin
  x:=statspack.snap;
  dbms_output.put_line('Statspack snap created: ' || to_char(x));
end;
/

select dbms_workload_repository.create_snapshot from dual;

prompt ** Child cursor status from v\$sql after taking the snapshots: **
select count(*),sum(executions) from v\$sql where sql_id = '&&sql_id';

prompt ** Verify captured data from AWR and Statspack repositories: **

set lines 500 pagesize 9999 tab off
col execs for 999,999,999
col avg_etime for 999,999.999
col avg_lio for 999,999,999.9
col begin_interval_time for a30
col node for 99999
break on plan_hash_value on startup_time skip 1


prompt
select ss.snap_id, ss.instance_number node, begin_interval_time, sql_id, plan_hash_value,
nvl(executions_delta,0) execs,
nvl(rows_processed_delta,0) rows_processed,
nvl(rows_processed_delta,0)/nvl(executions_delta,1) rows_processed_per_exec,
(elapsed_time_delta/decode(nvl(executions_delta,0),0,1,executions_delta))/1000000 avg_etime,
(buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta)) avg_lio,
(disk_reads_delta/decode(nvl(disk_reads_delta,0),0,1,executions_delta)) avg_pio
from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT SS
where sql_id = '&&sql_id'
and ss.snap_id = S.snap_id
and ss.instance_number = S.instance_number
order by 1, 2, 3
/

prompt 'Statspack captured exec stats:'
select snap_id, executions from stats\$sql_summary where sql_id = '&&sql_id' order by snap_id;

spool off

EOF
