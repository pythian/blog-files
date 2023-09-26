#!/usr/bin/env bash

#for rcfile in trace-overhead-no-think-time/trc-ovrhd/* 
for dir in trace-overhead-.5-sec-think-time trace-overhead-no-think-time
do
	echo
	echo "dir: $dir"
	echo

	for traceLevel in 0 8 12
	do
		testNumber=0
		echo "  Trace Level: $traceLevel"
		for rcfile in $dir/trc-ovrhd/*-$traceLevel-*.log
		do
			(( testNumber++ ))
			basefile=$(basename $rcfile)
			xactCount=$(awk '{ x+=$2 }END{printf("%10d\n",x)}'  $rcfile)
			printf "     Test: %1d  Transactions: %8d\n" $testNumber $xactCount
		done
		echo
	done
done

echo

