#!/usr/bin/env bash


# run these several times
# pause-at-exit will timeout in 20 seconds for unattended running

for i in {1..8}
do

	./sqlrun-trace-overhead.sh no-trace 

	./sqlrun-trace-overhead.sh trace 8

	./sqlrun-trace-overhead.sh trace 12
done


