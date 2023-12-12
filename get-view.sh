#!/usr/bin/env bash

username=jkstill
password=grok
db='ora192rac-scan/pdb1.jks.com'


SQL="$@"

[[ -z $SQL ]] && {
	echo
	echo "Please provide a SQL statement that uses view(s)"
	echo
	exit 1
}

#echo "working on: $SQL"

unset SQLPATH
export SQL

sqlplus -L -S /nolog <<-EOF | ./format-sql.pl

	--connect "$username/$password@$db"
	connect jkstill/grok@'ora192rac-scan/pdb1.jks.com'

	@@get-view '$SQL'

	exit;

EOF
