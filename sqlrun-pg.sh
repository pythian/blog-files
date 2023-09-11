#!/bin/bash		

#  psql postgres://benchmark:grok@ubuntu-20-pg02:5432/postgres

sessions=1
runtime=5

./sqlrun.pl \
	--exe-mode sequential \
	--driver Pg \
	--port 5432 \
	--host 'ubuntu-20-pg02' \
	--connect-mode flood \
	--tx-behavior rollback \
	--exe-delay 0.1 \
	--db postgres \
	--username benchmark \
	--password password \
	--max-sessions $sessions \
	--runtime $runtime 
	#--exit-trigger
	#--debug 
	##--trace 
	#--timer-test
