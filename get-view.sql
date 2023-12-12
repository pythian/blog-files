
set serveroutput on size unlimited
set linesize 32767 trimspool on
set pagesize 0
set head off term off echo off pause off feed off verify off

-- for pipeline
set term on

spool view.txt

declare
	l_clob clob;
begin

	dbms_utility.expand_sql_text (
		--input_sql_text  => 'select * from dual',
		input_sql_text  => '&1',
		output_sql_text => l_clob
	);

	dbms_output.put_line(l_clob);

end;
/

spool off


set linesize 200 trimspool on
set pagesize 100
set head on term on feed on

