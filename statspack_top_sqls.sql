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
-- Purpose: Reporting SQL performance related statistics as they appear in the "SQL ordered by" 
--          Statspack's report sections for a time period provided as an input parameter.
--          Script's core logic is based on Oracle's $ORACLE_HOME/rdbms/admin/sprepins.sql (StatsPack 
--          Report Instance) script. sprepins.sql is not required to execute statspack_top_sqls.sql.           
--          Script output is wide, so it's suggested to spool the output to a file for easier viewing.
--
--
-- Usage:  Start statspack_top_sqls.sql, and provide the input parameters as illustrated below
--
-- Example:
--  
-- SQL> @statspack_top_sqls.sql
-- List SQL by [elapsed_time | cpu_time | buffer_gets | disk_reads | executions | parse_calls | max_sharable_mem | max_version_count | cluster_wait_time]:
-- 
-- Enter a value - default "elapsed_time" : /* provide one of the above attributes to order the reported SQLs by */
-- 
-- 
-- Instances in this Statspack schema
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--    DB Id    Inst Num DB Name      Instance     Host
-- ----------- -------- ------------ ------------ -------------
--  1558102526        1 ORCL         orcl1        ol7-122-rac1
--  1558102526        2 ORCL         orcl2        ol7-122-rac2
-- 
-- 
-- Enter DBID to analyze - default "1558102526" :  /* enter DBID to analyze */
-- Enter instance number or "all" to analyze all instancs for DBID = 1558102526 - default "all" : /* report data for a specific RAC instance or all of them */
-- 
-- 
-- Enter begin time for report [DD-MON-YYYY HH24:MI] - default "30-APR-2020 10:54" : /* specify time period to analyze */
-- Enter end time for report [DD-MON-YYYY HH24:MI] - default "30-APR-2020 22:54" : 
 
 

-- SCRIPT

-- Below values are taken from $ORACLE_HOME/rdbms/admin/sprepcon.sql, some of them are modified 

-- Number of Rows of SQL to display in each SQL section of the report
define top_n_sql = 65

-- Number of rows of SQL text to print in the SQL sections of the report for each hash_value
-- define num_rows_per_hash = 4;
-- Comment: default is 4, however we need to define it as 1, otherwise there will be duplicate rows in the output, 
-- one for each line of SQL from stats$sqltext. If more than 1 line of SQL is requred, consider using a 
-- "BREAK ON" sqlplus formatting clause including all of the relevant columns, so they don't repeat for each 
-- SQL text line 
define num_rows_per_hash = 1   

-- Filter which restricts the rows of SQL shown in the SQL sections of the 
-- report to be the top N pct
define top_pct_sql = 1.0



set lin 1000 pagesize 9999 tab off trimspool on feedback off verify off heading on newpage none arraysize 1000

-- order SQL-s by one of the below attributes: 
PROMPT
PROMPT List SQL by [elapsed_time | cpu_time | buffer_gets | disk_reads | executions | parse_calls | max_sharable_mem | max_version_count | cluster_wait_time]: 
PROMPT 
ACCEPT top_n_by_attribute CHAR PROMPT 'Enter a value - default "elapsed_time" : ' default elapsed_time


whenever sqlerror exit;
begin
IF lower('&top_n_by_attribute') not in ('elapsed_time','cpu_time','buffer_gets',
                                        'disk_reads','executions','parse_calls',
                                        'max_sharable_mem','max_version_count','cluster_wait_time') 
THEN
  raise_application_error(-20200, '''&top_n_by_attribute'' is not a valid option.');   
END IF;
end;
/
whenever sqlerror continue;


column dbbid      new_val dbid      heading "DB Id"     format 9999999999 just c;
column instt_num  heading "Inst Num"  format 99999;
column instt_name heading "Instance"  format a12;
column dbb_name   heading "DB Name"   format a12;
column host       heading "Host"      format a32;

prompt
prompt
prompt Instances in this Statspack schema
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  select distinct 
         dbid            dbbid
       , instance_number instt_num
       , db_name         dbb_name
       , instance_name   instt_name
       , host_name       host
    from stats$database_instance
order by instance_name, instance_number, dbid;

PROMPT
PROMPT
ACCEPT p_dbid     CHAR PROMPT 'Enter DBID to analyze - default "&dbid" : ' default '&dbid'
ACCEPT p_inst_num CHAR PROMPT 'Enter instance number or "all" to analyze all instancs for DBID = &p_dbid - default "all" : ' default 'all'
PROMPT
PROMPT 


SET TERMOUT OFF
column dt_s new_val dt_s
column dt_e new_val dt_e
select to_char(sysdate-12/24,'DD-MON-YYYY HH24:MI') dt_s,
       to_char(sysdate,'DD-MON-YYYY HH24:MI') dt_e
       from dual;
SET TERMOUT ON

ACCEPT start_date_time CHAR PROMPT 'Enter begin time for report [DD-MON-YYYY HH24:MI] - default "&dt_s" : ' default '&dt_s' 
ACCEPT   end_date_time CHAR PROMPT 'Enter end time for report [DD-MON-YYYY HH24:MI] - default "&dt_e" : ' default '&dt_e'
PROMPT
PROMPT 

col module    for a60
col SQL_TEXT  for a75
col DBtimemin for 99,990.99
col AAS       for 99,990.99
BREAK ON instance_number SKIP 1 ON b_snap_id skip 1 on e_snap_id on b_snap_time on e_snap_time on interval_min on DBtimemin on aas 

alter session set nls_date_format='DD-MON-YY HH24:MI:SS';
    
select /*+ cursor_sharing_exact */ topn.instance_number, 
       topn.b_snap_id, 
       topn.e_snap_id, 
       topn.b_snap_time, 
       topn.e_snap_time,
       topn.interval_min,
	   topn.DBtimemin,
	   topn.AAS,	   
       topn.old_hash_value hv,       
       round(delta_elapsed_time/1000000, 2) elapsed_time_sec,
       delta_executions executions,
       decode(delta_executions , 0, 0, round(delta_elapsed_time/1000000/delta_executions,2)) elapsed_per_exec_sec,
       decode(topn.dbtim, 0, 0 ,round(100*delta_elapsed_time/topn.dbtim, 2)) percent_of_dbtime_used,
       round(delta_cpu_time/1000000, 2) cpu_time_sec,       
       decode(delta_executions , 0, 0, round(delta_cpu_time/delta_executions/1000, 2)) cpu_time_ms_per_exec,        
       delta_disk_reads physical_reads,
       decode(delta_executions , 0, 0, round(delta_disk_reads/delta_executions, 2)) physical_reads_per_execution,       
       delta_buffer_gets buffer_gets, 
       decode(delta_executions , 0, 0, round(delta_buffer_gets/delta_executions, 2)) gets_per_execution, 
       delta_rows_processed rows_processed,
       decode(delta_executions , 0, 0, round(delta_rows_processed/delta_executions, 2)) rows_processed_per_execution,
       delta_parse_calls parse_calls,
       round(max_sharable_mem/1024, 2) max_sharable_mem_kb,
       round(last_sharable_mem/1024, 2) last_sharable_mem_kb,
       max_version_count,
       last_version_count,
       delta_version_count,
       round(delta_cluster_wait_time/1000000, 2) cluster_wait_time_sec,
       decode(delta_elapsed_time, 0, 0, round(100*delta_cluster_wait_time/delta_elapsed_time, 2)) cwt_percent_of_elapsed_time,
       round(avg_hard_parse_time/1000, 2) avg_hard_parse_time_ms,               
       topn.module,  
       translate(st.sql_text, chr(9) || chr(13) || chr(10), '   ') sql_text -- convert tabs and newlines to spaces   
  from ( select *
           from ( select gtt.*, 
                         row_number() over (partition by gtt.dbid, gtt.instance_number, gtt.e_snap_id 
                                                order by gtt.dbid, gtt.instance_number, gtt.e_snap_id, 
                                                         case when '&top_n_by_attribute' = 'elapsed_time'      then delta_elapsed_time 
                                                              when '&top_n_by_attribute' = 'cpu_time'          then delta_cpu_time
                                                              when '&top_n_by_attribute' = 'buffer_gets'       then delta_buffer_gets
                                                              when '&top_n_by_attribute' = 'disk_reads'        then delta_disk_reads
                                                              when '&top_n_by_attribute' = 'executions'        then delta_executions
                                                              when '&top_n_by_attribute' = 'parse_calls'       then delta_parse_calls
                                                              when '&top_n_by_attribute' = 'max_sharable_mem'  then max_sharable_mem
                                                              when '&top_n_by_attribute' = 'max_version_count' then max_version_count
                                                              when '&top_n_by_attribute' = 'cluster_wait_time' then delta_cluster_wait_time
                                                              else delta_elapsed_time 
                                                          end desc
                                           ) rn
                    from 
                    (                                                 
                       with sysstat as
                             (
                                select /*consider enabling in case of TEMP TABLE TRANSFORMATION performance related issues: "qb_name(sysstat) inline"*/ * from
                                  (select instance_number, snap_id, dbid, name, value 
                                     from STATS$SYSSTAT 
                                    where name in ('physical reads', 
                                                   'session logical reads', 
                                                   'execute count', 
                                                   'parse count (total)'
                                                  )
                                  ) pivot
                                     (sum(value) for (name) in
                                             ('physical reads'                physical_reads,
                                              'session logical reads'  session_logical_reads,
                                              'execute count'                  execute_count,
                                              'parse count (total)'               tot_parses                 
                                              )
                                      )
                                ) ,
                       sys_time_model as (
                             select /*consider enabling in case of TEMP TABLE TRANSFORMATION performance related issues: "qb_name(sys_tm_model) inline"*/ * from
                               (select instance_number, snap_id, dbid, stat_name, value 
                                  from stats$sys_time_model stm, stats$time_model_statname tms                           
                                 where stm.stat_id = tms.stat_id
                                   and tms.stat_name in ('DB CPU', 'DB time')                                                    
                               ) pivot
                                  (sum(value) for (stat_name) in
                                          ('DB CPU'  dbcpu,
                                           'DB time' dbtime)
                                  )
                             ) ,                                                                                
                       snaps as
                        (select s.dbid, 
                               s.instance_number,                               
                               s.b b_snap_id, 
                               s.e e_snap_id, 
                               s.bt b_snap_time,
                               s.et e_snap_time, 
                               round((s.et - s.bt)*24*60,2) interval_min,              
                               sys_time_model_e.dbtime - sys_time_model_b.dbtime dbtim
                               , round((sys_time_model_e.dbtime - sys_time_model_b.dbtime)/1000000/60,2)  DBtimemin
                               , round(((sys_time_model_e.dbtime - sys_time_model_b.dbtime)/1000000/60)/((s.et - s.bt)*24*60),2) "AAS"
                               , s.esmt
                               , s.evc
                               , sysstat_e.session_logical_reads - sysstat_b.session_logical_reads session_logical_reads
                               , sysstat_e.physical_reads - sysstat_b.physical_reads  physical_reads
                               , sysstat_e.execute_count - sysstat_b.execute_count execute_count
                               , sysstat_e.tot_parses - sysstat_b.tot_parses tot_parses                                  
                               , sys_time_model_e.dbcpu - sys_time_model_b.dbcpu dbcpu
                               , i.parallel
                          from sys_time_model sys_time_model_b
                             , sys_time_model sys_time_model_e                                                                                                                    
                             , (select dbid, 
                                       instance_number, 
                                       snap_id b, 
                                       snap_time bt, 
                                       lead(snap_id) over (order by dbid, instance_number, snap_id) e, 
                                       lead(snap_time) over (order by dbid, instance_number, snap_id) et,                                        
                                       startup_time b_startup_time,
                                       lead(startup_time) over (order by dbid, instance_number, snap_id) e_startup_time,
                                       lead(sharable_mem_th) over (order by dbid, instance_number, snap_id) esmt, 
                                       lead(version_count_th) over (order by dbid, instance_number, snap_id) evc
                                  from stats$snapshot) s                             
                             , sysstat sysstat_b
                             , sysstat sysstat_e
                             , stats$database_instance i
                         where sys_time_model_b.snap_id           = s.b
                           and sys_time_model_b.instance_number   = s.instance_number
                           and sys_time_model_b.dbid              = s.dbid
                           and sys_time_model_e.snap_id           = s.e
                           and sys_time_model_e.instance_number   = s.instance_number
                           and sys_time_model_e.dbid              = s.dbid                                                                                                                                                                           
                           and s.b_startup_time                   = s.e_startup_time                                                                                 
                           and sysstat_b.snap_id                  = s.b                          
                           and sysstat_b.dbid                     = s.dbid
                           and sysstat_b.instance_number          = s.instance_number
                           and sysstat_e.snap_id                  = s.e                          
                           and sysstat_e.dbid                     = s.dbid
                           and sysstat_e.instance_number          = s.instance_number                                                                                                             
                           and i.dbid                             = s.dbid
                           and i.instance_number                  = s.instance_number
                           and i.startup_time                     = s.b_startup_time                                                                                
                           and s.dbid                             = to_number('&p_dbid') 
                           and (lower('&p_inst_num') = 'all' or s.instance_number = to_number('&p_inst_num'))
                           and s.bt                              >= to_date('&start_date_time','DD-MON-YYYY HH24:MI')
                           and s.et                              <= to_date('&end_date_time','DD-MON-YYYY HH24:MI')
                        )    
                         select old_hash_value, s2.instance_number, s2.b_snap_id, s2.e_snap_id, s2.b_snap_time, 
                                s2.e_snap_time, s2.dbid, s2.interval_min, s2.dbtim, s2.dbcpu, s2.DBtimemin, 
                                s2.AAS, s2.session_logical_reads, s2.physical_reads, s2.execute_count, 
                                s2.tot_parses, lev1.text_subset, lev1.module,
                                lev1.delta_buffer_gets, lev1.delta_executions, lev1.delta_cpu_time, 
                                lev1.delta_elapsed_time, lev1.avg_hard_parse_time, lev1.delta_disk_reads, 
                                lev1.delta_parse_calls,
                                lev1.max_sharable_mem, lev1.last_sharable_mem,
                                lev1.delta_version_count, lev1.max_version_count, lev1.last_version_count,
                                lev1.delta_cluster_wait_time, lev1.delta_rows_processed, s2.parallel,
                                s2.esmt, s2.evc                                                            
                          from ( select -- sum deltas
                                        dbid,                                        
                                        snap_id, 
                                        instance_number,
                                        old_hash_value
                                      , text_subset
                                      , module
                                      , sum(case
                                            when ((snap_id = lev0.b_snap_id and prev_snap_id = -1) or (snap_id not in (lev0.b_snap_id,lev0.e_snap_id))) 
                                            then 0
                                            else
                                                 case when (address != prev_address) 
                                                        or (buffer_gets < prev_buffer_gets)
                                                      then buffer_gets
                                                      else buffer_gets - prev_buffer_gets
                                                 end
                                           end)                    delta_buffer_gets
                                      , sum(case
                                            when ((snap_id = lev0.b_snap_id and prev_snap_id = -1) or (snap_id not in (lev0.b_snap_id,lev0.e_snap_id))) 
                                            then 0
                                            else
                                                 case when (address != prev_address)
                                                        or (executions < prev_executions)
                                                      then executions
                                                      else executions - prev_executions
                                                 end
                                            end)                   delta_executions
                                      , sum(case
                                            when ((snap_id = lev0.b_snap_id and prev_snap_id = -1) or (snap_id not in (lev0.b_snap_id,lev0.e_snap_id))) 
                                            then 0
                                            else
                                                 case when (address != prev_address)
                                                        or (cpu_time < prev_cpu_time)
                                                      then cpu_time
                                                      else cpu_time - prev_cpu_time
                                                 end
                                            end)                  delta_cpu_time
                                      , sum(case
                                            when ((snap_id = lev0.b_snap_id and prev_snap_id = -1) or (snap_id not in (lev0.b_snap_id,lev0.e_snap_id))) 
                                            then 0
                                            else
                                                 case when (address != prev_address)
                                                        or (elapsed_time < prev_elapsed_time)
                                                      then elapsed_time
                                                      else elapsed_time - prev_elapsed_time
                                                 end
                                            end)                  delta_elapsed_time
                                      , avg(case
                                            when ((snap_id = lev0.b_snap_id and prev_snap_id = -1) or (snap_id not in (lev0.b_snap_id,lev0.e_snap_id))) 
                                            then 0
                                            else avg_hard_parse_time
                                            end)                  avg_hard_parse_time
                                      , sum(case
                                            when ((snap_id = lev0.b_snap_id and prev_snap_id = -1) or (snap_id not in (lev0.b_snap_id,lev0.e_snap_id))) 
                                            then 0
                                            else
                                                 case when (address != prev_address)
                                                        or (disk_reads < prev_disk_reads)
                                                      then disk_reads
                                                      else disk_reads - prev_disk_reads
                                                 end
                                            end)                   delta_disk_reads
                                      , sum(case
                                            when ((snap_id = lev0.b_snap_id and prev_snap_id = -1) or (snap_id not in (lev0.b_snap_id,lev0.e_snap_id))) 
                                            then 0
                                            else
                                                 case when (address != prev_address)
                                                        or (parse_calls < prev_parse_calls)
                                                      then parse_calls
                                                      else parse_calls - prev_parse_calls
                                                 end
                                            end)                   delta_parse_calls
                                      , max(sharable_mem)          max_sharable_mem
                                      , sum(case when snap_id = lev0.e_snap_id
                                                 then last_sharable_mem
                                                 else 0
                                            end)                   last_sharable_mem
                                      , sum(case
                                            when ((snap_id = lev0.b_snap_id and prev_snap_id = -1) or (snap_id not in (lev0.b_snap_id,lev0.e_snap_id))) 
                                            then 0
                                            else
                                                 case when (address != prev_address)
                                                        or (version_count < prev_version_count)
                                                      then version_count
                                                      else version_count - prev_version_count
                                                 end
                                            end)                   delta_version_count
                                      , max(version_count)         max_version_count
                                      , sum(case when snap_id = lev0.e_snap_id
                                                 then last_version_count
                                                 else 0
                                            end)                   last_version_count
                                      , sum(case
                                            when ((snap_id = lev0.b_snap_id and prev_snap_id = -1) or (snap_id not in (lev0.b_snap_id,lev0.e_snap_id))) 
                                            then 0
                                            else
                                                 case when (address != prev_address)
                                                        or (cluster_wait_time < prev_cluster_wait_time)
                                                      then cluster_wait_time
                                                      else cluster_wait_time - prev_cluster_wait_time
                                                 end
                                            end)                   delta_cluster_wait_time
                                      , sum(case
                                            when ((snap_id = lev0.b_snap_id and prev_snap_id = -1) or (snap_id not in (lev0.b_snap_id,lev0.e_snap_id))) 
                                            then 0
                                            else
                                                 case when (address != prev_address)
                                                        or (rows_processed < prev_rows_processed)
                                                      then rows_processed
                                                      else rows_processed - prev_rows_processed
                                                 end
                                            end)                   delta_rows_processed
                                  from (select /* commented out the first_rows hint from sprepins.sql - alternatively use "qb_name(sql_sum) index(s)" */ 
                                               snaps.dbid,
                                               s.snap_id,
                                               snaps.b_snap_id,
                                               snaps.e_snap_id,
                                               s.instance_number
                                             , old_hash_value
                                             , text_subset
                                             , module
                                             , (lag(snap_id, 1, -1) 
                                               over (partition by old_hash_value
                                                                , s.dbid
                                                                , s.instance_number
                                                    order by snap_id, b_snap_id))    prev_snap_id
                                             , (lead(snap_id, 1, -1)
                                               over (partition by old_hash_value
                                                                , s.dbid
                                                                , s.instance_number
                                                    order by snap_id, b_snap_id))    next_snap_id
                                             , address
                                             ,(lag(address, 1, hextoraw(0)) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_address
                                             , buffer_gets
                                             ,(lag(buffer_gets, 1, 0) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_buffer_gets
                                             , cpu_time
                                             ,(lag(cpu_time, 1, 0) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_cpu_time
                                             , executions
                                             ,(lag(executions, 1, 0) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_executions
                                             , elapsed_time
                                             ,(lag(elapsed_time, 1, 0) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_elapsed_time
                                             , avg_hard_parse_time
                                             , disk_reads
                                             ,(lag(disk_reads, 1, 0) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_disk_reads
                                             , parse_calls
                                             ,(lag(parse_calls, 1, 0) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_parse_calls
                                             , sharable_mem
                                             ,(last_value(sharable_mem) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   last_sharable_mem
                                             ,(lag(sharable_mem, 1, 0) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_sharable_mem
                                             , version_count
                                             ,(lag(version_count, 1, 0) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_version_count
                                             ,(last_value(version_count) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   last_version_count
                                             , cluster_wait_time
                                             ,(lag(cluster_wait_time, 1, 0) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_cluster_wait_time
                                             , rows_processed
                                             ,(lag(rows_processed, 1, 0) 
                                               over (partition by old_hash_value 
                                                                , s.dbid
                                                                , s.instance_number
                                                     order by snap_id, b_snap_id))   prev_rows_processed
                                        from stats$sql_summary s, snaps                                                                               
                                       where 
                                         ((s.snap_id = snaps.b_snap_id) or (s.snap_id = snaps.e_snap_id))
                                         and s.dbid            = snaps.dbid
                                         and s.instance_number = snaps.instance_number                                         
                                       ) lev0
                                group by dbid,
                                         instance_number ,
                                         snap_id, 
                                         old_hash_value
                                       , text_subset
                                       , module
                               ) lev1, snaps s2
                         where 
                           s2.instance_number = lev1.instance_number
                           and s2.dbid = lev1.dbid
                           and lev1.snap_id = s2.e_snap_id                            
                           and ( 
                               delta_buffer_gets       > 0
                            or delta_executions        > 0
                            or delta_cpu_time          > 0
                            or delta_disk_reads        > 0
                            or delta_parse_calls       > 0
                            or max_sharable_mem       >= s2.esmt
                            or max_version_count      >= s2.evc
                            or delta_cluster_wait_time > 0 )                    
                    ) gtt                    
                   where ('&top_n_by_attribute' = 'elapsed_time'      and decode(gtt.dbtim, 0, 2, 100*delta_elapsed_time/gtt.dbtim) > decode(gtt.dbtim, 0, 1, &&top_pct_sql))
                      or ('&top_n_by_attribute' = 'cpu_time'          and decode(gtt.dbcpu, 0, 2, null, 2, 100*delta_cpu_time/gtt.dbcpu) > decode(gtt.dbcpu, 0, 1, null, 2, &&top_pct_sql))                      
                      or ('&top_n_by_attribute' = 'buffer_gets'       and 100*delta_buffer_gets/gtt.session_logical_reads > &&top_pct_sql )
                      or ('&top_n_by_attribute' = 'disk_reads'        and gtt.physical_reads > 0 and 100*delta_disk_reads/gtt.physical_reads > &&top_pct_sql  )
                      or ('&top_n_by_attribute' = 'executions'        and 100*delta_executions/gtt.execute_count > &&top_pct_sql )
                      or ('&top_n_by_attribute' = 'parse_calls'       and 100*delta_parse_calls/gtt.tot_parses > &&top_pct_sql )
                      or ('&top_n_by_attribute' = 'max_sharable_mem'  and max_sharable_mem > gtt.esmt)
                      or ('&top_n_by_attribute' = 'max_version_count' and max_version_count > gtt.evc)
                      or ('&top_n_by_attribute' = 'cluster_wait_time' and delta_cluster_wait_time > 0 and gtt.parallel  = 'YES') 
                ) x          
          where rn <= &&top_n_sql
          order by instance_number asc, 
                   b_snap_id asc,  
                   case when '&top_n_by_attribute' = 'elapsed_time'      then delta_elapsed_time 
                        when '&top_n_by_attribute' = 'cpu_time'          then delta_cpu_time
                        when '&top_n_by_attribute' = 'buffer_gets'       then delta_buffer_gets
                        when '&top_n_by_attribute' = 'disk_reads'        then delta_disk_reads
                        when '&top_n_by_attribute' = 'executions'        then delta_executions
                        when '&top_n_by_attribute' = 'parse_calls'       then delta_parse_calls
                        when '&top_n_by_attribute' = 'max_sharable_mem'  then max_sharable_mem
                        when '&top_n_by_attribute' = 'max_version_count' then max_version_count
                        when '&top_n_by_attribute' = 'cluster_wait_time' then delta_cluster_wait_time
                        else delta_elapsed_time 
                    end desc
       ) topn
     , stats$sqltext st
 where st.old_hash_value(+) = topn.old_hash_value
   and st.text_subset(+)    = topn.text_subset   
   and st.piece             < &&num_rows_per_hash -- number of rows of SQL text to output    
 order by topn.instance_number asc, 
          topn.b_snap_id asc,                      
          case when '&top_n_by_attribute' = 'elapsed_time'        then topn.delta_elapsed_time 
               when '&top_n_by_attribute' = 'cpu_time'            then topn.delta_cpu_time
               when '&top_n_by_attribute' = 'buffer_gets'         then topn.delta_buffer_gets
               when '&top_n_by_attribute' = 'disk_reads'          then topn.delta_disk_reads
               when '&top_n_by_attribute' = 'executions'          then topn.delta_executions
               when '&top_n_by_attribute' = 'parse_calls'         then topn.delta_parse_calls
               when '&top_n_by_attribute' = 'max_sharable_mem'    then topn.max_sharable_mem
               when '&top_n_by_attribute' = 'max_version_count'   then topn.max_version_count
               when '&top_n_by_attribute' = 'cluster_wait_time'   then topn.delta_cluster_wait_time
               else delta_elapsed_time 
           end desc,                    
          topn.old_hash_value, 
          st.piece;          