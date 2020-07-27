-- May 2020
-- Jure Bratina, Pythian
--
-- Purpose: Retrieve OS and DB related metrics from the Statspack repository for a given time range. 
--          Inspired by the AWR repository analysis scripts from Chapter 5 (Sizing Exadata) in the "Oracle 
--          Exadata Recipes: A Problem-Solution Approach" book, and John Beresniewicz's AWR1page project: 
--          https://github.com/jberesni/AWR1page             
--          Script output is wide, so it's suggested to spool the output to a file for easier viewing.
--
--
-- Usage:  start statspack_load_trends.sql, and provide the input parameters as illustrated below
--
--
-- Example:
-- SQL> @statspack_load_trends.sql
-- 
-- 
-- Instances in this Statspack schema
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--    DB Id   |Inst Num|DB Name     |Instance    |Host
-- -----------|--------|------------|------------|-------------
--  1558102526|       1|ORCL        |orcl1       |ol7-122-rac1
--  1558102526|       2|ORCL        |orcl2       |ol7-122-rac2
-- 
-- 
-- Enter DBID to analyze - default "1558102526" :   /* enter DBID to analyze */
-- Enter instance number or "all" to analyze all instancs for DBID = 1558102526 - default "all" : /* report data for a specific RAC instance or all of them */
-- 
-- 
-- Enter begin time for report [DD-MON-YYYY HH24:MI] - default "30-APR-2020 10:54" : /* specify time period to analyze */
-- Enter end time for report [DD-MON-YYYY HH24:MI] - default "30-APR-2020 22:54" : 
 


set lines 1500 pages 9999 tab off

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

define usec = 1000000
define csec = 100

set arraysize 1000
set termout on
set echo off verify off
set tab off trimspool on feedback off heading on newpage none


-- Formatting used for plotting/charting

col snap_start_end                 format a17             head 'Snap ID start-end'
col begin_snap_time_ch             format a15             head 'Begin Snap Time'
col end_snap_time_ch               format a15             head 'End Snap Time'
col instance_number                format 99              head 'Instance Number'
col elapsed_min                    format 999.99          head 'Elapsed Mins'
col cpu_info                       format a19             head 'CPU #Cores;#Threads'               
col cpu_time_available             format 9,999,990.00    head 'Tot CPU Time Avail [Cores] (s)'
col dbtime                         format a57             head "[FG CPU+WAIT]  =           [FG CPU] +          [FG WAIT] "
col tm_aas_fg_bg                   format 99,990.0        head 'AAS [FG+BG]'
col tm_aas_fg                      format 99,990.0        head 'AAS [FG]'
col tm_aas_bg                      format 99,990.0        head 'AAS [BG]'
col tm_cpu_fg_bg_aas               format 99,990.0        head 'AAS on CPU [FG+BG]'                
col tm_cpu_fg_bg_aas_norm          format 99,990.0        head 'AAS on CPU [FG+BG] NPC'  

col tm_cpu_fg_aas                  format 99,990.0        head 'AAS on CPU [FG]'                   
col tm_cpu_fg_aas_norm             format 99,990.0        head 'AAS on CPU [FG] NPC'     

col tm_cpu_bg_aas                  format 99,990.0        head 'AAS on CPU [BG]'                  
col tm_cpu_bg_aas_norm             format 99,990.0        head 'AAS on CPU [BG] NPC'    


col tm_wait_fg_bg_aas              format 99,990.0        head 'AAS wait [FG+BG]'
col tm_wait_fg_aas                 format 99,990.0        head 'AAS wait [FG]'
col tm_wait_bg_aas                 format 99,990.0        head 'AAS wait [BG]'
                                                          
col rman_aas                       format 99990.0         head 'AAS RMAN CPU '
                                                          
col os_load                        format 990.0           head 'Tot OS Load@end_snap'
col os_busy_aap                    format 99,990.0        head 'AAP OS BUSY'                      
col os_busy_aap_norm               format 99,990.0        head 'AAP OS BUSY NPC'        
col os_sys_aap                     format 99,990.0        head 'AAP OS SYS'        
col os_user_aap                    format 99,990.0        head 'AAP OS USER'
col os_iowait_aap                  format 99,990.0        head 'AAP OS IOWAIT'

col logons_current                 format 999,990.0       head 'Logons Current'
col logons_cumulative_ps           format 990.0           head 'Logons/s'
col execute_count_ps               format 9,999,990.0     head 'Executes/s'
col sqlnet_client_trip_ps          format 999,999,990.0   head 'SQL*Net roundtrips to/from client/s'
col sqlnet_dblink_trip_ps          format 999,999,990.0   head 'SQL*Net roundtrips to/from dblink/s'
col sqlnet_client_bts_recvd_ps     format 999,999,990.0   head 'Bytes received via SQL*Net from client/s' 
col sqlnet_client_bts_sent_ps      format 999,999,990.0   head 'Bytes sent via SQL*Net to client/s'
col sqlnet_dblink_bts_recvd_ps     format 999,999,990.0   head 'Bytes received via SQL*Net from dblink/s'
col sqlnet_dblink_bts_sent_ps      format 999,999,990.0   head 'Bytes sent via SQL*Net to dblink/s'
col cluster_wait_time_ps           format     999,990.0   head 'Cluster wait time/s'
col session_logical_reads_ps       format 999,999,990.0   head 'Session logical reads/s'
col db_block_changes_ps            format 999,999,990.0   head 'DB block changes/s'
col consistent_changes_ps          format 999,999,990.0   head 'Consistent changes/sec'
col dbcr_ur_ps                     format 999,999,990.0   head 'Consistent reads  undo rec applied/s'
col physical_reads_ps              format     999,990.0   head 'Physical reads/s'
col physical_writes_ps             format     999,990.0   head 'Physical writes/s'
col physical_read_IO_requests_ps   format     999,990.0   head 'Physical read IO requests/s'
col physical_write_IO_requests_ps  format     999,990.0   head 'Physical write IO requests/s'
col tot_parses_ps                  format     999,990.0   head 'Parses total/s'
col h_parses_ps                    format     999,990.0   head 'Hard parses/s'
col f_parses_ps                    format     999,990.0   head 'Parse failures/s'
col d_parses_ps                    format     999,990.0   head 'Parse describe/s'
col user_calls_ps                  format     999,990.0   head 'User calls/s'
col user_commits_ps                format     999,990.0   head 'User commits/s'
col user_rollbacks_ps              format     999,990.0   head 'User rollbacks/s'
col redo_size_ps                   format 999,999,990.0   head 'Redo size bytes/s'
col redo_writes_ps                 format 999,999,990.0   head 'Redo writes/s'
col rb_undo_rec_applied_ps         format     999,990.0   head 'Rollback changes undo records applied/s'
col queries_par_pm                 format     999,990.0   head 'Queries parallelized/Total'
col DML_stmts_par_pm               format     999,990.0   head 'DML statements parallelized/Total'
col not_downg                      format     999,990.0   head 'PX oper not downgraded/Total'
col down_ser                       format     999,990.0   head 'PX oper downgraded to serial/Total'
col down_99                        format     999,990.0   head 'PX oper downgraded 75 to 99 pct/Total'
col down_75                        format     999,990.0   head 'PX oper downgraded 50 to 75 pct/Total'
col down_50                        format     999,990.0   head 'PX oper downgraded 25 to 50 pct/Total'
col down_25                        format     999,990.0   head 'PX oper downgraded 1 to 25 pct/Total'



/*
-- Formatting used for visual file inspection

col snap_start_end                 format a15             head 'Snap ID|start-end'
col begin_snap_time_ch             format a15             head 'Begin Snap|Time'
col end_snap_time_ch               format a15             head 'End Snap|Time'
col instance_number                format 99              head 'Instance|Number'
col elapsed_min                    format 999.99          head 'Elapsed|Mins'
col cpu_info                       format a19             head 'CPU|#Cores;#Threads'               
col cpu_time_available             format 9,999,990.00    head 'Tot CPU Time|Avail [Cores] (s)'
col dbtime                         format a57             head "  DB Time (s)            DB CPU (s)                     |[FG CPU+WAIT]  =           [FG CPU] +          [FG WAIT] "
col tm_aas_fg_bg                   format 99,990.0        head 'AAS|[FG+BG]'
col tm_aas_fg                      format 99,990.0        head 'AAS|[FG]'
col tm_aas_bg                      format 99,990.0        head 'AAS|[BG]'
col tm_cpu_fg_bg_aas               format 99,990.0        head 'AAS on CPU|[FG+BG]'                
col tm_cpu_fg_bg_aas_norm          format 99,990.0        head 'AAS on CPU|[FG+BG] NPC'  

col tm_cpu_fg_aas                  format 99,990.0        head 'AAS on|CPU [FG]'                   
col tm_cpu_fg_aas_norm             format 99,990.0        head 'AAS on CPU|[FG] NPC'     

col tm_cpu_bg_aas                  format 99,990.0        head 'AAS on|CPU [BG]'                  
col tm_cpu_bg_aas_norm             format 99,990.0        head 'AAS on CPU|[BG] NPC'    


col tm_wait_fg_bg_aas              format 99,990.0        head 'AAS wait|[FG+BG]'
col tm_wait_fg_aas                 format 99,990.0        head 'AAS wait|[FG]'
col tm_wait_bg_aas                 format 99,990.0        head 'AAS wait|[BG]'
                                                          
col rman_aas                       format 99990.0         head 'AAS RMAN CPU '
                                                          
col os_load                        format 990.0           head 'Tot OS|Load@end_snap'
col os_busy_aap                    format 99,990.0        head 'AAP OS BUSY'                      
col os_busy_aap_norm               format 99,990.0        head 'AAP OS|BUSY NPC'        
col os_sys_aap                     format 99,990.0        head 'AAP OS|SYS'        
col os_user_aap                    format 99,990.0        head 'AAP OS|USER'
col os_iowait_aap                  format 99,990.0        head 'AAP OS|IOWAIT'

col logons_current                 format 999,990.0       head 'Logons|Current'
col logons_cumulative_ps           format 990.0           head 'Logons/s'
col execute_count_ps               format 9,999,990.0     head 'Executes/s'
col sqlnet_client_trip_ps          format 999,999,990.0   head 'SQL*Net roundtrips|to/from client/s'
col sqlnet_dblink_trip_ps          format 999,999,990.0   head 'SQL*Net roundtrips|to/from dblink/s'
col sqlnet_client_bts_recvd_ps     format 999,999,990.0   head 'Bytes received via|SQL*Net from client/s' 
col sqlnet_client_bts_sent_ps      format 999,999,990.0   head 'Bytes sent via|SQL*Net to client/s'
col sqlnet_dblink_bts_recvd_ps     format 999,999,990.0   head 'Bytes received via|SQL*Net from dblink/s'
col sqlnet_dblink_bts_sent_ps      format 999,999,990.0   head 'Bytes sent via|SQL*Net to dblink/s'
col cluster_wait_time_ps           format     999,990.0   head 'Cluster wait|time/s'
col session_logical_reads_ps       format 999,999,990.0   head 'Session logical|reads/s'
col db_block_changes_ps            format 999,999,990.0   head 'DB block|changes/s'
col consistent_changes_ps          format 999,999,990.0   head 'Consistent|changes/sec'
col dbcr_ur_ps                     format 999,999,990.0   head 'Consistent reads |undo rec applied/s'
col physical_reads_ps              format     999,990.0   head 'Physical|reads/s'
col physical_writes_ps             format     999,990.0   head 'Physical|writes/s'
col physical_read_IO_requests_ps   format     999,990.0   head 'Physical read|IO requests/s'
col physical_write_IO_requests_ps  format     999,990.0   head 'Physical write|IO requests/s'
col tot_parses_ps                  format     999,990.0   head 'Parses|total/s'
col h_parses_ps                    format     999,990.0   head 'Hard|parses/s'
col f_parses_ps                    format     999,990.0   head 'Parse|failures/s'
col d_parses_ps                    format     999,990.0   head 'Parse|describe/s'
col user_calls_ps                  format     999,990.0   head 'User|calls/s'
col user_commits_ps                format     999,990.0   head 'User|commits/s'
col user_rollbacks_ps              format     999,990.0   head 'User|rollbacks/s'
col redo_size_ps                   format 999,999,990.0   head 'Redo size|bytes/s'
col redo_writes_ps                 format 999,999,990.0   head 'Redo|writes/s'
col rb_undo_rec_applied_ps         format     999,990.0   head 'Rollback changes|undo records applied/s'
col queries_par_pm                 format     999,990.0   head 'Queries|parallelized/Total'
col DML_stmts_par_pm               format     999,990.0   head 'DML statements|parallelized/Total'
col not_downg                      format     999,990.0   head 'PX oper not|downgraded/Total'
col down_ser                       format     999,990.0   head 'PX oper downgraded|to serial/Total'
col down_99                        format     999,990.0   head 'PX oper downgraded|75 to 99 pct/Total'
col down_75                        format     999,990.0   head 'PX oper downgraded|50 to 75 pct/Total'
col down_50                        format     999,990.0   head 'PX oper downgraded|25 to 50 pct/Total'
col down_25                        format     999,990.0   head 'PX oper downgraded|1 to 25 pct/Total'
*/

col startup_time                   noprint
col p_startup_time                 noprint
col end_snap_time                  noprint
col elapsed                        noprint

set colsep "|"
set echo off

select /*+ cursor_sharing_exact */
  instance_number, 
  snap_start_end, 
  begin_snap_time_ch,
  end_snap_time_ch,
  end_snap_time,
  elapsed,      
  elapsed_min,        
  num_cpu_cores || '; ' || num_cpus cpu_info,
  cpu_time_available,
  --
  -- (TIMEMODEL["background elapsed time"]+TIMEMODEL["DB time"])/elapsed = foreground + background AAS
  ( (dbtime - dbtime_p) + (background_elapsed_time - background_elapsed_time_p))/&usec/elapsed tm_aas_fg_bg ,                    
  --
  -- TIMEMODEL["DB time"]/elapsed = foreground AAS
  (dbtime - dbtime_p)/&usec/elapsed tm_aas_fg,
  --
  -- (TIMEMODEL["background elapsed time"])/elapsed = background AAS
  (background_elapsed_time - background_elapsed_time_p)/&usec/elapsed tm_aas_bg ,           
  --
  -- (TIMEMODEL["DB CPU"]+TIMEMODEL["background cpu time"])/elapsed = foreground + background AAS on CPU  ;  CPU core count normalized foreground + background AAS on CPU
   ( dbcpu - dbcpu_p + background_cpu_time - background_cpu_time_p)/&usec/elapsed  tm_cpu_fg_bg_aas,            
   ( dbcpu - dbcpu_p + background_cpu_time - background_cpu_time_p)/&usec/elapsed/num_cpu_cores tm_cpu_fg_bg_aas_norm,            
  --
  -- TIMEMODEL["DB CPU"]/elapsed = foreground AAS on CPU ; CPU core count normalized foreground AAS on CPU
  (dbcpu - dbcpu_p)/&usec/elapsed tm_cpu_fg_aas,
  (dbcpu - dbcpu_p)/&usec/elapsed/num_cpu_cores tm_cpu_fg_aas_norm,  
  --
  -- TIMEMODEL["background_cpu_time"]/elapsed = background AAS on CPU ; CPU core count normalized background AAS on CPU
  (background_cpu_time - background_cpu_time_p)/&usec/elapsed tm_cpu_bg_aas,   
  (background_cpu_time - background_cpu_time_p)/&usec/elapsed/num_cpu_cores tm_cpu_bg_aas_norm,
  --        
  -- ((TIMEMODEL["DB time"]+TIMEMODEL["background elapsed time"]) - (TIMEMODEL["DB CPU"]+TIMEMODEL["background cpu time"]))/elapsed = foreground + background wait expressed as AAS                
  (
   ( (dbtime - dbtime_p) + (background_elapsed_time - background_elapsed_time_p) )  -
   ( (dbcpu - dbcpu_p)  + (background_cpu_time - background_cpu_time_p) ) 
  )/&usec/elapsed tm_wait_fg_bg_aas,      
  --
  -- (TIMEMODEL["DB time"] - TIMEMODEL["DB CPU"])/elapsed = foreground wait expressed as AAS
  ( (dbtime - dbtime_p) - (dbcpu - dbcpu_p) )/&usec/elapsed tm_wait_fg_aas,  
  --
  -- (TIMEMODEL["background elapsed time"] - TIMEMODEL["background cpu time"])/elapsed = background wait expressed as AAS
  ( (background_elapsed_time - background_elapsed_time_p ) -
    (background_cpu_time - background_cpu_time_p) )/&usec/elapsed tm_wait_bg_aas,
  --
  -- TIMEMODEL["RMAN cpu time (backup/restore)"]/elapsed = RMAN time expressed as AAS
  (rman_cpu_time - rman_cpu_time_p)/&usec/elapsed rman_aas,  
  lpad(trim(to_char((dbtime - dbtime_p)/&usec,'9,999,990.00')),14)  || 
    ' = ' || 
    lpad(trim(to_char((dbcpu - dbcpu_p)/&usec,'9,999,990.00')) ||
     ' ' ||     
     lpad(trim(to_char(100*(dbcpu - dbcpu_p)/(dbtime - dbtime_p),'990')),3),17) ||
     '% + ' ||     
    lpad(trim(to_char(((dbtime - dbtime_p) - (dbcpu - dbcpu_p))/&usec,'9,999,990.00')) ||
    ' ' ||
    lpad(trim(to_char(100*((dbtime - dbtime_p) - (dbcpu - dbcpu_p))/(dbtime - dbtime_p),'990')),3),17) ||
     '%' dbtime,
  os_load,
  os_busy_aap,
  os_busy_aap_norm,    
  os_user_aap,
  os_sys_aap,
  os_iowait_aap,
  logons_current ,
  logons_cumulative_ps,
  user_calls_ps,
  execute_count_ps,  
  sqlnet_client_trip_ps,
  sqlnet_dblink_trip_ps,
  sqlnet_client_bts_recvd_ps,
  sqlnet_client_bts_sent_ps,
  sqlnet_dblink_bts_recvd_ps,
  sqlnet_dblink_bts_sent_ps,
  cluster_wait_time_ps,
  session_logical_reads_ps,
  db_block_changes_ps,
  consistent_changes_ps,
  dbcr_ur_ps,
  physical_reads_ps,
  physical_writes_ps,
  physical_read_IO_requests_ps, 
  physical_write_IO_requests_ps,
  tot_parses_ps,
  h_parses_ps,
  d_parses_ps,
  f_parses_ps,  
  user_commits_ps,
  user_rollbacks_ps,
  redo_size_ps,
  redo_writes_ps,
  rb_undo_rec_applied_ps,                
  queries_par_pm,
  DML_stmts_par_pm,
  not_downg,
  down_ser,
  down_99,
  down_75,
  down_50,
  down_25,
  startup_time, 
  p_startup_time
from
(
with snaps as 
 ( /* stats$snapshot */
    select begin_snap_id,
           end_snap_id,           
           dbid,
           begin_snap_time, 
           end_snap_time,
           instance_number,            
           86400*(end_snap_time - begin_snap_time) elapsed,
           startup_time, 
           p_startup_time 
    from (
      select dbid, 
             instance_number, 
             snap_id end_snap_id, 
             snap_time end_snap_time,            
             startup_time, 
             lag(snap_id) over (partition by dbid, instance_number order by dbid, instance_number, snap_id) begin_snap_id, 
             lag(snap_time) over (partition by dbid, instance_number order by dbid, instance_number, snap_id) begin_snap_time,                                                
             lag(startup_time) over (partition by dbid, instance_number order by dbid, instance_number, snap_id) p_startup_time         
        from stats$snapshot
       where dbid = to_number('&p_dbid')
         and (lower('&p_inst_num') = 'all' or instance_number = to_number('&p_inst_num'))
         and snap_time between to_date('&start_date_time','DD-MON-YYYY HH24:MI') and to_date('&end_date_time','DD-MON-YYYY HH24:MI')  
    )        
 )  
select  snaps.instance_number, 
        snaps.begin_snap_id || '-' || snaps.end_snap_id snap_start_end, 
        to_char(begin_snap_time,'DD-MON-RR HH24:MI') begin_snap_time_ch,
        to_char(end_snap_time,'DD-MON-RR HH24:MI') end_snap_time_ch,                                  
        snaps.end_snap_time,  
        snaps.elapsed,      
        round(snaps.elapsed/60, 2) elapsed_min,        
        osstat.num_cpu_cores,
        osstat.num_cpus,
        osstat.num_cpu_cores * elapsed cpu_time_available,
        timemodel.dbtime,
        timemodel.dbcpu,
        timemodel.background_elapsed_time,
        timemodel.background_cpu_time,
        timemodel.rman_cpu_time,
        lag(timemodel.dbtime,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id) dbtime_p,         
        lag(timemodel.dbcpu,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id) dbcpu_p,                                                     
        lag(timemodel.background_elapsed_time,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id) background_elapsed_time_p,                
        lag(timemodel.background_cpu_time,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id) background_cpu_time_p,                                      
        lag(timemodel.rman_cpu_time,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id) rman_cpu_time_p,
        --
        -- ** OS **                      
        osstat.load os_load,
        (osstat.busy_time - lag(osstat.busy_time,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id))/&csec/elapsed  os_busy_aap,                 
        (osstat.busy_time - lag(osstat.busy_time,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id))/&csec/elapsed/osstat.num_cpu_cores os_busy_aap_norm,          
        ((osstat.sys_time - lag(osstat.sys_time,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/&csec/elapsed os_sys_aap,
        ((osstat.user_time - lag(osstat.user_time,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/&csec/elapsed os_user_aap,
        ((osstat.iowait_time - lag(osstat.iowait_time,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/&csec/elapsed os_iowait_aap,        
        --
        -- ** SYSSTAT **        
        sysstat.logons_current ,
        ((sysstat.logons_cumulative - lag (sysstat.logons_cumulative,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed  logons_cumulative_ps,
        ((sysstat.execute_count - lag (sysstat.execute_count,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed execute_count_ps,
        ((sysstat.sqlnet_client_trip - lag (sysstat.sqlnet_client_trip,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed sqlnet_client_trip_ps,
        ((sysstat.sqlnet_dblink_trip - lag (sysstat.sqlnet_dblink_trip,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed sqlnet_dblink_trip_ps,
        ((sysstat.sqlnet_client_bts_recvd - lag (sysstat.sqlnet_client_bts_recvd,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed sqlnet_client_bts_recvd_ps,
        ((sysstat.sqlnet_client_bts_sent - lag (sysstat.sqlnet_client_bts_sent,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed  sqlnet_client_bts_sent_ps,
        ((sysstat.sqlnet_dblink_bts_recvd - lag (sysstat.sqlnet_dblink_bts_recvd,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed sqlnet_dblink_bts_recvd_ps,
        ((sysstat.sqlnet_dblink_bts_sent - lag (sysstat.sqlnet_dblink_bts_sent,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed sqlnet_dblink_bts_sent_ps,
        ((sysstat.cluster_wait_time - lag (sysstat.cluster_wait_time,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed cluster_wait_time_ps,
        ((sysstat.session_logical_reads - lag (sysstat.session_logical_reads,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed session_logical_reads_ps,
        ((sysstat.db_block_changes - lag (sysstat.db_block_changes,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed db_block_changes_ps,
        ((sysstat.consistent_changes - lag (sysstat.consistent_changes,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed consistent_changes_ps,
        ((sysstat.dbcr_ur - lag (sysstat.dbcr_ur,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed dbcr_ur_ps,
        ((sysstat.physical_reads - lag (sysstat.physical_reads,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed physical_reads_ps,
        ((sysstat.physical_writes - lag (sysstat.physical_writes,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed physical_writes_ps,
        ((sysstat.physical_read_IO_requests - lag (sysstat.physical_read_IO_requests,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed physical_read_IO_requests_ps, 
        ((sysstat.physical_write_IO_requests - lag (sysstat.physical_write_IO_requests,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed physical_write_IO_requests_ps,
        ((sysstat.tot_parses - lag (sysstat.tot_parses,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed tot_parses_ps,
        ((sysstat.h_parses - lag (sysstat.h_parses,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed h_parses_ps,
        ((sysstat.d_parses - lag (sysstat.d_parses,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed d_parses_ps,
        ((sysstat.f_parses - lag (sysstat.f_parses,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed f_parses_ps,
        ((sysstat.user_calls - lag (sysstat.user_calls,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed user_calls_ps,
        ((sysstat.user_commits - lag (sysstat.user_commits,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed user_commits_ps,
        ((sysstat.user_rollbacks - lag (sysstat.user_rollbacks,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed user_rollbacks_ps,
        ((sysstat.redo_size - lag (sysstat.redo_size,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed redo_size_ps,
        ((sysstat.redo_writes - lag (sysstat.redo_writes,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed redo_writes_ps,
        ((sysstat.rb_undo_rec_applied - lag (sysstat.rb_undo_rec_applied,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id)))/elapsed rb_undo_rec_applied_ps,                
        ((sysstat.queries_par - lag (sysstat.queries_par,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id))) queries_par_pm,
        ((sysstat.DML_stmts_par - lag (sysstat.DML_stmts_par,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id))) DML_stmts_par_pm,
        ((sysstat.not_downg - lag (sysstat.not_downg,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id))) not_downg,
        ((sysstat.down_ser - lag (sysstat.down_ser,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id))) down_ser,
        ((sysstat.down_99 - lag (sysstat.down_99,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id))) down_99,
        ((sysstat.down_75 - lag (sysstat.down_75,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id))) down_75,
        ((sysstat.down_50 - lag (sysstat.down_50,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id))) down_50,
        ((sysstat.down_25 - lag (sysstat.down_25,1,0) over (partition by snaps.dbid, snaps.instance_number order by snaps.end_snap_id))) down_25,
        startup_time, p_startup_time                                                
 from
 ( /* stats$osstat */
     select *
       from
       (select s.instance_number,s.snap_id,s.dbid,n.stat_name,s.value 
          from stats$osstat s, stats$osstatname n, snaps
         where s.osstat_id = n.osstat_id
           and stat_name in ('NUM_CPUS',
                             'NUM_CPU_CORES',
                             'BUSY_TIME',
                             'LOAD',
                             'USER_TIME',
                             'SYS_TIME',
                             'IOWAIT_TIME')
           and snaps.end_snap_id=s.snap_id
           and snaps.dbid=s.dbid
           and snaps.instance_number=s.instance_number                           
       ) pivot
      (sum(value) for (stat_name)
            in ('NUM_CPUS'       as num_cpus,
                'NUM_CPU_CORES'  as num_cpu_cores,
                'BUSY_TIME'      as busy_time,
                'LOAD'           as load,
                'USER_TIME'      as user_time,
                'SYS_TIME'       as sys_time, 
                'IOWAIT_TIME'    as iowait_time
                )
      )
  ) osstat,
  ( /* stats$sys_time_model */
     select * from
          (select m.instance_number,m.snap_id,m.dbid,n.stat_name,m.value 
             from stats$sys_time_model m, stats$time_model_statname n, snaps
            where m.stat_id = n.stat_id
              and stat_name in ('DB time',
                                'DB CPU',
                                'background cpu time',
                                'background elapsed time',
                                'RMAN cpu time (backup/restore)'
                                )
              and snaps.end_snap_id=m.snap_id
              and snaps.dbid=m.dbid
              and snaps.instance_number=m.instance_number               
     ) pivot
     (sum(value) for (stat_name)
          in ('DB time'                        as dbtime, 
              'DB CPU'                         as dbcpu, 
              'background cpu time'            as background_cpu_time,
              'background elapsed time'        as background_elapsed_time,
              'RMAN cpu time (backup/restore)' as rman_cpu_time
              )
     )
  ) timemodel,
  ( /* stats$sysstat */
    select * from
        (select s.instance_number, s.snap_id, s.dbid, s.name, s.value 
           from stats$sysstat s, snaps
           where s.name in ( 'logons current',                        
                             'logons cumulative',                     
                             'execute count',                         
                             'SQL*Net roundtrips to/from client',     
                             'SQL*Net roundtrips to/from dblink',    
                             'bytes received via SQL*Net from client',
                             'bytes sent via SQL*Net to client',      
                             'bytes received via SQL*Net from dblink',
                             'bytes sent via SQL*Net to dblink',      
                             'cluster wait time',                     
                             'session logical reads',                 
                             'db block changes',                      
                             'consistent changes',                    
                             'data blocks consistent reads - undo records applied',                           
                             'physical reads',                      
                             'physical writes',                     
                             'physical read IO requests',           
                             'physical write IO requests',          
                             'parse count (total)',                 
                             'parse count (hard)',                  
                             'parse count (failures)',              
                             'parse count (describe)',             
                             'user calls',                          
                             'user commits',                        
                             'user rollbacks',                      
                             'redo size',                           
                             'redo writes',                         
                             'rollback changes - undo records applied',    
                             'queries parallelized',                       
                             'DML statements parallelized',                
                             'Parallel operations not downgraded',         
                             'Parallel operations downgraded to serial',          
                             'Parallel operations downgraded 75 to 99 pct',       
                             'Parallel operations downgraded 50 to 75 pct',      
                             'Parallel operations downgraded 25 to 50 pct',       
                             'Parallel operations downgraded 1 to 25 pct'       
                            )
             and snaps.end_snap_id=s.snap_id
             and snaps.dbid=s.dbid
             and snaps.instance_number=s.instance_number      
    ) pivot
    (sum(value) for (name) in
        ('logons current'                                  logons_current, 
         'logons cumulative'                            logons_cumulative, 
         'execute count'                                    execute_count,
         'SQL*Net roundtrips to/from client'           sqlnet_client_trip, 
         'SQL*Net roundtrips to/from dblink'           sqlnet_dblink_trip, 
         'bytes received via SQL*Net from client' sqlnet_client_bts_recvd,
         'bytes sent via SQL*Net to client'        sqlnet_client_bts_sent, 
         'bytes received via SQL*Net from dblink' sqlnet_dblink_bts_recvd,
         'bytes sent via SQL*Net to dblink'        sqlnet_dblink_bts_sent, 
         'cluster wait time'                            cluster_wait_time,
         'session logical reads'                    session_logical_reads, -- = "db block gets" + "consistent gets"
         'db block changes'                              db_block_changes,
         'consistent changes'                          consistent_changes,
         'data blocks consistent reads - undo records applied'    dbcr_ur,                           
         'physical reads'                                  physical_reads, 
         'physical writes'                                physical_writes, 
         'physical read IO requests'            physical_read_IO_requests,
         'physical write IO requests'          physical_write_IO_requests,
         'parse count (total)'                                 tot_parses,
         'parse count (hard)'                                    h_parses,
         'parse count (failures)'                                f_parses,
         'parse count (describe)'                                d_parses,
         'user calls'                                          user_calls,
         'user commits'                                      user_commits,
         'user rollbacks'                                  user_rollbacks,
         'redo size'                                            redo_size,
         'redo writes'                                        redo_writes,
         'rollback changes - undo records applied'    rb_undo_rec_applied,
         'queries parallelized'                               queries_par,
         'DML statements parallelized'                      DML_stmts_par,
         'Parallel operations not downgraded'                   not_downg,
         'Parallel operations downgraded to serial'              down_ser,       
         'Parallel operations downgraded 75 to 99 pct'            down_99,       
         'Parallel operations downgraded 50 to 75 pct'            down_75,      
         'Parallel operations downgraded 25 to 50 pct'            down_50,       
         'Parallel operations downgraded 1 to 25 pct'             down_25         
         )
    )
  ) sysstat, snaps
where snaps.end_snap_id=osstat.snap_id
  and snaps.dbid=osstat.dbid
  and snaps.instance_number=osstat.instance_number
  and snaps.end_snap_id=timemodel.snap_id
  and snaps.dbid=timemodel.dbid
  and snaps.instance_number=timemodel.instance_number
  and snaps.end_snap_id=sysstat.snap_id
  and snaps.dbid=sysstat.dbid
  and snaps.instance_number=sysstat.instance_number             
) 
where elapsed > 0
and (startup_time = p_startup_time or p_startup_time is null)
order by instance_number, end_snap_time;