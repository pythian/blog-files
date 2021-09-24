-- May 2020
-- Jure Bratina, Pythian
--
--
-- DISCLAIMER
-- 
-- This script was prepared by the author in a personal capacity and does not constitute technical advice 
-- or recommendation from Pythian. Content in this script is provided AS-IS, without representations or 
-- warranties of any kind and Pythian expressly disclaims all warranties, including express, statutory or 
-- implied warranties of non-infringement, merchantability,  and fitness for a particular purpose. 
-- Pythian does not make any warranty regarding the accuracy, adequacy, validity, reliability, availability, 
-- or completeness of the Content provided in this script. You understand that the Content may contain 
-- defects or errors. Your access to and use of the Content in this script is at your own risk. Pythian 
-- will not accept any liability arising out of your access to or use of the Content provided in this script. 
--
--
--
-- Purpose: Quick and dirty script to evaluate execution trends for a particular SQL.
--          
--    Note: * The script doesn't (yet) verify whether there was an instance restart between two snapshots, so 
--            be aware of this when suspiciously high numbers are reported.
--          * When executions are reported as 0, I'm assuming executions=1 when calculating averages
--
--




set lin 3000 pagesize 9999 tab off
alter session set nls_date_format='dd-mon-yy hh24:mi';


col EXACT_MATCHING_SIGNATURE for 99999999999999999999999999
col FORCE_MATCHING_SIGNATURE for 99999999999999999999999999

select 
  snap_time,
  snap_id,       
  dbid, 
  instance_number,       
  plan_hash_value,
  executions,  
  round(elapsed_time_sec/1000000, 2) elapsed_time_sec_total,
  round(disk_reads/decode(nvl(executions,0),0,1,executions),2) disk_reads_per_exec,
  round(buffer_gets/decode(nvl(executions,0),0,1,executions),2) buffer_gets_per_exec,
  round(rows_processed/decode(nvl(executions,0),0,1,executions),2) rows_processed_per_exec,
  round(elapsed_time_sec/1000000/decode(nvl(executions,0),0,1,executions),4) elapsed_time_per_exec,
  round(cpu_time_sec/1000000/decode(nvl(executions,0),0,1,executions),4) cpu_time_per_exec,
  round(sorts/decode(nvl(executions,0),0,1,executions),2) sorts_per_exec,
  round(fetches/decode(nvl(executions,0),0,1,executions),2) fetches_per_exec,
  round(px_servers_executions/decode(nvl(executions,0),0,1,executions),2) px_servers_executions_per_exec,
  round(end_of_fetch_count/decode(nvl(executions,0),0,1,executions),2) end_of_fetch_count_per_exec,
  round(invalidations/decode(nvl(executions,0),0,1,executions),2) invalidations_per_exec,
  round(loads/decode(nvl(executions,0),0,1,executions),2) loads_per_exec,
  round(parse_calls/decode(nvl(executions,0),0,1,executions),2) parse_calls_per_exec,
  round(direct_writes/decode(nvl(executions,0),0,1,executions),2) direct_writes_per_exec,
  round(application_wait_time/decode(nvl(executions,0),0,1,executions),2) application_wait_time_per_exec,
  round(concurrency_wait_time/decode(nvl(executions,0),0,1,executions),2) concurrency_wait_time_per_exec,
  round(cluster_wait_time/decode(nvl(executions,0),0,1,executions),2) cluster_wait_time_per_exec,
  round(user_io_wait_time/decode(nvl(executions,0),0,1,executions),2) user_io_wait_time_per_exec,
  round(plsql_exec_time/decode(nvl(executions,0),0,1,executions),2) plsql_exec_time_per_exec,
  round(java_exec_time/decode(nvl(executions,0),0,1,executions),2) java_exec_time_per_exec,
  round(version_count/decode(nvl(executions,0),0,1,executions),2) version_count_per_exec,
  round(avg_hard_parse_time/decode(nvl(executions,0),0,1,executions),2) avg_hard_parse_time_per_exec,
  outline_category, 
  sql_profile,
  program_id, 
  program_line#,
  exact_matching_signature, 
  force_matching_signature 
from 
(
select 
  snap_time,
  snap_id,       
  dbid, 
  instance_number,   
  plan_hash_value,    
  case when (address != prev_address) or (prev_address is null) or (executions < executions_prev) then executions
                                                        else executions - executions_prev
  end executions,
  case when (address != prev_address) or (prev_address is null) or (disk_reads < disk_reads_prev) then disk_reads
                                                        else disk_reads - disk_reads_prev
  end disk_reads,
  case when (address != prev_address) or (prev_address is null) or (buffer_gets < buffer_gets_prev) then buffer_gets
                                                        else buffer_gets - buffer_gets_prev
  end buffer_gets,
  case when (address != prev_address) or (prev_address is null) or (rows_processed < rows_processed_prev) then rows_processed
                                                        else rows_processed - rows_processed_prev
  end rows_processed,  
  case when (address != prev_address) or (prev_address is null) or (elapsed_time < elapsed_time_prev) then elapsed_time
                                                        else elapsed_time - elapsed_time_prev
  end elapsed_time_sec,
  case when (address != prev_address) or (prev_address is null) or (cpu_time < cpu_time_prev) then cpu_time
                                                        else cpu_time - cpu_time_prev
  end cpu_time_sec,
  case when (address != prev_address) or (prev_address is null) or (sorts < sorts_prev) then sorts
                                                        else sorts - sorts_prev
  end sorts,
  case when (address != prev_address) or (prev_address is null) or (fetches < fetches_prev) then fetches
                                                        else fetches - fetches_prev
  end fetches,
  case when (address != prev_address) or (prev_address is null) or (px_servers_executions < px_servers_executions_prev) then px_servers_executions
                                                        else px_servers_executions - px_servers_executions_prev
  end px_servers_executions,
  case when (address != prev_address) or (prev_address is null) or (end_of_fetch_count < end_of_fetch_count_prev) then end_of_fetch_count
                                                        else end_of_fetch_count - end_of_fetch_count_prev
  end end_of_fetch_count,
  case when (address != prev_address) or (prev_address is null) or (invalidations < invalidations_prev) then invalidations
                                                        else invalidations - invalidations_prev
  end invalidations,
  case when (address != prev_address) or (prev_address is null) or (loads < loads_prev) then loads
                                                        else loads - loads_prev
  end loads,
  case when (address != prev_address) or (prev_address is null) or (parse_calls < parse_calls_prev) then parse_calls
                                                        else parse_calls - parse_calls_prev
  end parse_calls,
  case when (address != prev_address) or (prev_address is null) or (direct_writes < direct_writes_prev) then direct_writes
                                                        else direct_writes - direct_writes_prev
  end direct_writes,
  case when (address != prev_address) or (prev_address is null) or (application_wait_time < application_wait_time_prev) then application_wait_time
                                                        else application_wait_time - application_wait_time_prev
  end application_wait_time,
  case when (address != prev_address) or (prev_address is null) or (concurrency_wait_time < concurrency_wait_time_prev) then concurrency_wait_time
                                                        else concurrency_wait_time - concurrency_wait_time_prev
  end concurrency_wait_time,
  case when (address != prev_address) or (prev_address is null) or (cluster_wait_time < cluster_wait_time_prev) then cluster_wait_time
                                                        else cluster_wait_time - cluster_wait_time_prev
  end cluster_wait_time,
  case when (address != prev_address) or (prev_address is null) or (user_io_wait_time < user_io_wait_time_prev) then user_io_wait_time
                                                        else user_io_wait_time - user_io_wait_time_prev
  end user_io_wait_time,
  case when (address != prev_address) or (prev_address is null) or (plsql_exec_time < plsql_exec_time_prev) then plsql_exec_time
                                                        else plsql_exec_time - plsql_exec_time_prev
  end plsql_exec_time,
  case when (address != prev_address) or (prev_address is null) or (java_exec_time < java_exec_time_prev) then java_exec_time
                                                        else java_exec_time - java_exec_time_prev
  end java_exec_time,
  case when (address != prev_address) or (prev_address is null) or (version_count < version_count_prev) then version_count
                                                        else version_count - version_count_prev
  end version_count,
  case when (address != prev_address) or (prev_address is null) or (avg_hard_parse_time < avg_hard_parse_time_prev) then avg_hard_parse_time
                                                        else avg_hard_parse_time - avg_hard_parse_time_prev
  end avg_hard_parse_time,
  outline_category, 
  sql_profile,
  program_id, 
  program_line#,
  exact_matching_signature, 
  force_matching_signature      
from 
(
select sn.snap_time,
       sn.snap_id,       
       s.dbid, 
       s.instance_number,
       pu.plan_hash_value,                    
       s.executions, lag(s.executions) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) executions_prev, 
       s.disk_reads,  lag(s.disk_reads) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) disk_reads_prev,
       s.buffer_gets,  lag(s.buffer_gets) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) buffer_gets_prev,
       s.rows_processed,  lag(s.rows_processed) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) rows_processed_prev,
       s.elapsed_time, lag(s.elapsed_time) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) elapsed_time_prev,       
	   s.cpu_time, lag(s.cpu_time) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) cpu_time_prev,
       s.address, lag(s.address) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) prev_address,	   
	   s.sorts, lag(s.sorts) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) sorts_prev,	   	   
	   s.fetches, lag(s.fetches) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) fetches_prev,	   
	   s.px_servers_executions, lag(s.px_servers_executions) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) px_servers_executions_prev,	   
	   s.end_of_fetch_count, lag(s.end_of_fetch_count) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) end_of_fetch_count_prev,	   	   
	   s.invalidations, lag(s.invalidations) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) invalidations_prev,	   
	   s.loads, lag(s.loads) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) loads_prev,	   
	   s.parse_calls, lag(s.parse_calls) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) parse_calls_prev,	   	   
	   s.direct_writes, lag(s.direct_writes) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) direct_writes_prev,	   	   
	   s.application_wait_time, lag(s.application_wait_time) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) application_wait_time_prev,	   
	   s.concurrency_wait_time, lag(s.concurrency_wait_time) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) concurrency_wait_time_prev,	   
	   s.cluster_wait_time, lag(s.cluster_wait_time) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) cluster_wait_time_prev,	   
	   s.user_io_wait_time, lag(s.user_io_wait_time) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) user_io_wait_time_prev,	   	   
	   s.plsql_exec_time, lag(s.plsql_exec_time) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) plsql_exec_time_prev,
	   s.java_exec_time, lag(s.java_exec_time) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) java_exec_time_prev,	   	  
	   s.version_count, lag(s.version_count) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) version_count_prev,	   
	   s.avg_hard_parse_time, lag(s.avg_hard_parse_time) over (partition by s.old_hash_value, s.dbid, s.instance_number order by s.snap_id) avg_hard_parse_time_prev,	   	   	   	  
	   s.outline_category, s.sql_profile,
       s.program_id, s.program_line#,s.exact_matching_signature, s.force_matching_signature	   
from stats$snapshot sn, stats$sql_summary s
left join stats$sql_plan_usage pu on (s.instance_number = pu.instance_number and s.dbid = pu.dbid and s.snap_id = pu.snap_id and s.old_hash_value = pu.old_hash_value)
where s.instance_number = sn.instance_number
  and s.dbid = sn.dbid
  and s.snap_id = sn.snap_id                 
  and s.sql_id = '&sql_id_1'
  -- and sn.snap_time > sysdate - 20
  -- and s.instance_number=1  
order by s.instance_number, s.snap_id
)
)
--where executions>0
order by instance_number, snap_id;
