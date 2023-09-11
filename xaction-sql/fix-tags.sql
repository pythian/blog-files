update (
select tag from sqlrun_insert where tag like 'SQLR-%' or tag like 'SQLRELAY-%'
)
set tag = 'RELAY' || substr(tag,instr(tag,'-')) 
/
