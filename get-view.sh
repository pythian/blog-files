#!/usr/bin/env bash

username=jkstill
password=grok
db='ora192rac-scan/pdb1.jks.com'
#db='ora192rac-scan/demo.jks.com'
export username password db

SQL="$@"

[[ -z $SQL ]] && {
	echo
	echo "Please provide a SQL statement that uses view(s)"
	echo
	exit 1
}

#echo "working on: $SQL"

#unset SQLPATH
export SQL

#sqlplus -L -S /nolog <<-EOF
sqlplus -L -S /nolog <<-EOF | ./format-sql.pl

	-- do not quote the name/passwor@db string
	-- ie. connect '$username/$password@$db' as that will not work
	--      connect '$username'/'$password'@'$db' also will not work
	connect $username/$password@$db

	@@get-view '$SQL'

	exit;

EOF

