
Oracle SQL Trace: Is it Safe for Production Use?
============================================================

Perhaps you have been approached by a client or manager and given the task of troubleshooting one or more slow running SQL statements.

The request may have been even more broad: an application is slow, it has been determined that that problem must be the database, and so now it is on the DBA's desk. And you are the DBA.

When trying to solve such problems it is not too unusual to start with an AWR report, examining the execution plans, and drilling down in ASH to determine where the problem lies.

While some good information may have been found, it may not quite enough information to determine the cause of the application slowness.

While ASH, AWR and execution plans may be good at showing you where there may be some problems, they are not always enough show you just where a problem lies.

The most accurate represenation of where time is spent during a database session is by invoking SQL Trace.

There are multiple methods for enabling SQL tracing:

- alter session set events '10046 trace name context forever, level [8|12]';
- sys.dbms_system.set_ev(sid(n), serial(n), 10046, 8, '')
- alter session set sql_trace=true;
- [dbms_monitor](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_MONITOR.html#GUID-951568BF-D798-4456-8478-15FEEBA0C78E)

The final method using `dbms_monitor` is considered the best choice.  

The `alter session` method requires that the user that is enabling tracing have the `alter session` privilege.
The `sys.dbms_system.set_ev` method requires DBA privileges.
And the `alter session set sql_trace=true` method is not useful, as the trace file will not contain any wait time values.

When requesting to run SQL Trace, the the client or responsible user may object to using SQL Trace due to the additional overhead that tracing may incur.

Of course there must be some overhead when tracing is enabled.

The question is this: Is the overhead more than the users can bear?

The answer to the question may depend on several factors regarding the issue in question:

- severity of the issue
- how badly it is impacting users
- the urgency of resolving the issue

The answer to these questions help determine if SQL Trace will impose an unbearable burden on the user of affected applications.

So, just how much perceived overhead is caused by SQL Trace?

The answer is as it is with many things: It depends.

If the issue is causing much interruption of users work, they may not mind if tracing is enabled, even if they do think it may have some negative impact.

In other cases, the impact may be less severe, and users (and manaagers) are leery of anything that may cause further delays.

We can consider the results of tests run with varying parameters, and find out the impact of enabling Oracle tracing.

## Test Configuration

The way to determine if the overhead is acceptable is do do some testing.

[sqlrun](https://github.com/jkstill/sqlrun) is a tool I developed for running SQL statements against a database using 1+ sessions. It is highly configurable, following are some of the parameters and configuration possibilities:

* number of sessions
* think time between executions
* connection timing
  * connect all simultaneously
  * connect as quickly as possible, in succession
  * interval between connections
* Multiple SQL statements can be run
* randomize frequency of statements run
* Placeholder values (bind variables) can be supplied from a text file.
* DML can be used
* PL/SQL blocks can be used

Testing will involve two servers: the database server, and the test software on another server.

Network latency between client and server is < 1ms.

Two sets of tests will be run

Note: 'no think time' means that the test SQL statements are run repeatedly in succession, as quickly as the client can submit them.

- no think time
  - latency is < 1ms
- local client, but with 0.5 seconds think time
  - each client will pause 0.5 seconds between executions

Each of those preceding tests will also run with multiple trace levels

- no tracing
- trace level 8
- trace level 12

There will be 50 clients per test.

All of the code and trace files used for this article are found here: [pythian blog - Oracle Trace Overhead](https://github.com/pythian/blog-files/tree/oracle-trace-overhead)

Further details are found in the README.md in the github repo.

## Test Environment

The test environment is as follows:

* Database Server:
  * ora192rac01 (one node of a 2 node RAC)
  * allocated 4 vCPUs
  * 16 G RAM
  * 1G network
* Client 
  * sqlrun, an Oracle Linux 7 VM
  * 3 vCPUs
  * 8G RAM

Oracle database is 19.12
Oracle clients are 19.16
Test software uses Perl 5, with the DBI and DBD::Oracle modules


## Compiling Test Results

The [mrskew](https://method-r.com/man/mrskew.pdf) utility is a tool created by [Method R](https://method-r.com/) (Cary Millsap and Jeff Holt).

It is used to generate metrics from Oracle SQL Trace files.

This testing makes use of the `mrskew` utility, and the `cull-snmfc.rc` file to skip 'SQL*Net message from client' events >= 1 second.


```text
# cull-snmfc.rc
# Jared Still 2023
# jkstill@gmail.com
# exlude snmfc (SQL*Net message from client) if >= 1 second

--init='

=encoding utf8

'

--where1='($name =~ q{message from client} and $af < 1) or ! ( $name =~ q{message from client})'
```

Using this rc file:  `mrskew --rc=cull-snfmc.rc`.

This is equivilent to: `mrskew --where1='($name =~ q{message from client} and $af < 1) or ! ( $name =~ q{message from client})'` on the command line.


If you are a user of the Method R Workbench, you may find this rc file useful.


### EVS Schema

EVS is the `Electric Vehicles Sighting` Schema.

The data was obtained from the [Electric Vehicle Population](https://catalog.data.gov/dataset/electric-vehicle-population-data) data set.

See [create-csv.sh](https://github.com/pythian/blog-files/blob/oracle-trace-overhead/create-ev-tables/create-csv.sh)

A subset of cities.csv and ev-models.csv will be used as placeholder values for the bind variables used in the test SQL files.


### The Test Transaction

The following SQL scripts will make up a transaction:

#### SQL/Oracle/ev-cities.sql

```sql
select county,city,state
from cities
where
        county = :1
        and city = :2
        and state = :3
```

#### SQL/Oracle/ev-insert.sql

```sql
insert into ev_sightings(make,model,county,city,state,date_sighted)
values (:1, :2, :3, :4, :5, sysdate)
```

#### SQL/Oracle/ev-location-select.sql

```sql
select count(*) ev_count
from ev_locations el
join cities ci on ci.city = el.city
        and ci.county = el.county
        and ci.state = el.state
        and el.make = :1
        and el.model = :2
        and el.county = :3
        and el.city = :4
        and el.state = :5
join ev_models m on m.make = el.make
        and m.model = el.model
```

#### SQL/Oracle/ev-select.sql

```sql
select make, model
from ev_models
where make = :1
	and model = :2
```

#### Bind Values

The values for the SQL placeholders are found in these three files:

```text
SQL/Oracle/cities.csv
SQL/Oracle/ev-models.csv
SQL/Oracle/ev-sightings.csv
```

### sqlrun-trace-overhead.sh

This script is used to call `sqlrun.pl`.

It accepts up to two parameters:

- no-trace
- trace [8|12]

sqlrun.pl will start 50 clients that run for 10 minutes.

The parameter `--exe-delay` was set to 0 for tests with no think time, and '0.5' for tests that allowed think time.

```bash
\#!/usr/bin/env bash

stMkdir () {
	mkdir -p "$@"

	[[ $? -ne 0 ]] && {
		echo
		echo failed to "mkdir -p $baseDir"
		echo
		exit 1
	}

}

\# convert to lower case
typeset -l rcMode=$1
typeset -l traceLevel=$2

set -u

[[ -z $rcMode ]] && {
	echo
	echo include 'trace' or 'no-trace' on the command line
	echo
	echo "eg: $0 [trace|no-trace]"
	echo
	exit 1
}

\# another method to convert to lower case
\#rcMode=${rcMode@L}

echo rcMode: $rcMode

declare traceArgs

case $rcMode in
	trace) 
		[[ -z "$traceLevel" ]] && { echo "please set trace level. eg $0 trace 8"; exit 1;}
		traceArgs=" --trace --trace-level $traceLevel ";;
	no-trace) 
		traceLevel=0
		traceArgs='';;
	*) echo 
		echo "arguments are [trace|no-trace] - case is unimportant"
		echo 
		exit 1;;
esac


db='ora192rac01/pdb1.jks.com'
#db='lestrade/orcl.jks.com'
username='evs'
password='evs'

baseDir=/mnt/vboxshare/trace-overhead
stMkdir -p $baseDir

ln -s $baseDir .

timestamp=$(date +%Y%m%d%H%M%S)
traceDir=$baseDir/trace/${rcMode}-${traceLevel}-${timestamp}
rcLogDir=$baseDir/trc-ovrhd
rcLogFile=$rcLogDir/xact-count-${rcMode}-${traceLevel}-${timestamp}.log 
traceFileID="TRC-OVRHD-$traceLevel-$timestamp"

[[ -n $traceArgs ]] && { traceArgs="$traceArgs --tracefile-id $traceFileID"; }

[[ $rcMode == 'trace' ]] && { stMkdir -p $traceDir; }


stMkdir -p $rcLogDir

./sqlrun.pl \
	--exe-mode sequential \
	--connect-mode flood \
	--tx-behavior commit \
	--max-sessions 50 \
	--exe-delay 0 \
	--db "$db" \
	--username $username \
	--password "$password" \
	--runtime 600 \
	--tracefile-id $traceFileID \
	--xact-tally \
	--xact-tally-file $rcLogFile \
	--pause-at-exit \
	--sqldir $(pwd)/SQL $traceArgs

\# do not continue until all sqlrun have exited
while :
do
	echo checking for perl sqlrun to exit completely
        chk=$(ps -flu$(id -un) | grep "[p]erl.*sqlrun")
        [[ -z $chk ]] && { break; }
        sleep 2
done

\# cheating a bit as I know where the trace files are on the server
\# ora192rac01:/u01/app/oracle/diag/rdbms/cdb/cdb1/trace/
[[ -n $traceArgs ]] && { 

	# get the trace files and remove them
	# space considerations require removing the trace files after retrieval
	rsync -av --remove-source-files oracle@ora192rac01:/u01/app/oracle/diag/rdbms/cdb/cdb1/trace/*${traceFileID}.trc ${traceDir}/

	# remove the .trm files
	ssh oracle@ora192rac01 rm /u01/app/oracle/diag/rdbms/cdb/cdb1/trace/*${traceFileID}.trm

	echo Trace files are in $traceDir/
	echo 
}

echo RC Log is $rcLogFile
echo 

```

### overhead.sh

The script `overhead.sh` was used to allow for unattended running of tests.

```bash
\#!/usr/bin/env bash


\# run these several times
\# pause-at-exit will timeout in 20 seconds for unattended running

for i in {1..3}
do

	./sqlrun-trace-overhead.sh no-trace 

	./sqlrun-trace-overhead.sh trace 8

	./sqlrun-trace-overhead.sh trace 12
done
```

## The Results

The results are interesting

First, let's consider the tests that used a 0.5 second think time.

The number of transactions per client are recorded in a log at the end of each run.

The results are stored in directories named for the tests.

Log results are summarized via `overhead-xact-sums.sh`


### overhead-xact-sums.sh

```bash
\#!/usr/bin/env bash

\#for rcfile in trace-overhead-no-think-time/trc-ovrhd/* 
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
```


### 0.5 Seconds Think Time

With 50 clients running for 10 minutes, with 0.5 seconds of think time between transactions, we should expect something near 60,000 total transactions.

( 50 sessons * 600 seconds ) / 0.5 seconds think time = 60,000

The number of transactions for all tests with 0.5 seconds think time was between 59177 and 59476 transactions, which is fairly close to the estimate.

The estimate of 60,000 did not account for any overhead, and so was optimistic.  It was not expected that 60k transactions would be reached.

At this rate, there are ~ 100 transactions per second being performed on the database.

Trace  Levels and Transaction  Counts


| Level  | Test #1 | Test #2 | Test #3 |
| ------ | ------- | ------- | ------- |
|   0    | 59386   | 59454   | 59476   |
|   8    | 59415   | 59365   | 59334   |
|  12    | 59411   | 59177   | 59200   |


The difference between tracing and not tracing would not be discernible by users.


We can see where the time was spent via level 8 and level 12 tracing, with a report for 1 set of the results each

Our built in think time of 0.5 seconds has resulted in rather skewed results 

```text
$ mrskew --rc=cull-snmfc.rc trace-overhead-.5-sec-think-time/trace/trace-8-20230920190529/*.trc
CALL-NAME                            DURATION       %    CALLS      MEAN       MIN       MAX
------------------------------  -------------  ------  -------  --------  --------  --------
SQL*Net message from client     29,805.268316   99.9%   74,678  0.399117  0.000096  0.659325
log file sync                       23.068209    0.1%   15,299  0.001508  0.000002  0.096168
EXEC                                 8.353714    0.0%   60,899  0.000137  0.000000  0.034094
enq: TX - index contention           2.494885    0.0%       99  0.025201  0.000067  0.037637
buffer busy waits                    1.395004    0.0%    1,916  0.000728  0.000000  0.014468
reliable message                     1.127232    0.0%      150  0.007515  0.000394  0.017183
FETCH                                0.518977    0.0%   44,852  0.000012  0.000000  0.000942
enq: SQ - contention                 0.287349    0.0%      159  0.001807  0.000011  0.004690
latch: cache buffers chains          0.267296    0.0%       89  0.003003  0.000000  0.013789
DLM cross inst call completion       0.191174    0.0%      268  0.000713  0.000000  0.014315
32 others                            1.042712    0.0%   92,879  0.000011  0.000000  0.025532
------------------------------  -------------  ------  -------  --------  --------  --------
TOTAL (42)                      29,844.014868  100.0%  291,288  0.102455  0.000000  0.659325
```

The 'think time' value of 1 second that was built into `cull-snmfc.rc` was changed from 1 to 0.5

```text
$ mrskew --rc=cull-snmfc.rc trace-overhead-.5-sec-think-time/trace/trace-8-20230920190529/*.trc
CALL-NAME                        DURATION       %    CALLS      MEAN       MIN       MAX
------------------------------  ---------  ------  -------  --------  --------  --------
log file sync                   23.068209   46.9%   15,299  0.001508  0.000002  0.096168
SQL*Net message from client     10.448160   21.2%   15,313  0.000682  0.000096  0.041637
EXEC                             8.353714   17.0%   60,899  0.000137  0.000000  0.034094
enq: TX - index contention       2.494885    5.1%       99  0.025201  0.000067  0.037637
buffer busy waits                1.395004    2.8%    1,916  0.000728  0.000000  0.014468
reliable message                 1.127232    2.3%      150  0.007515  0.000394  0.017183
FETCH                            0.518977    1.1%   44,852  0.000012  0.000000  0.000942
enq: SQ - contention             0.287349    0.6%      159  0.001807  0.000011  0.004690
latch: cache buffers chains      0.267296    0.5%       89  0.003003  0.000000  0.013789
DLM cross inst call completion   0.191174    0.4%      268  0.000713  0.000000  0.014315
32 others                        1.042712    2.1%   92,879  0.000011  0.000000  0.025532
------------------------------  ---------  ------  -------  --------  --------  --------
TOTAL (42)                      49.194712  100.0%  231,923  0.000212  0.000000  0.096168
```


Even though 50 clients ran for 600 seconds each, there was not much work done due to the 0.5 second think time built into the test.

Only 8.35 seconds were spent EXECuting ~60k database calls.

The rest is database overhead, mostly due to `log file sync` and normal client network traffic.

Here is the report for the Level 12 trace:

```text
$ mrskew --rc=cull-snmfc.rc trace-overhead-.5-sec-think-time/trace/trace-12-20230920191552/*.trc
CALL-NAME                        DURATION       %    CALLS      MEAN       MIN       MAX
------------------------------  ---------  ------  -------  --------  --------  --------
log file sync                   51.099850   64.7%   15,173  0.003368  0.000011  0.675610
SQL*Net message from client     11.407758   14.5%   15,293  0.000746  0.000099  0.234836
EXEC                             8.363528   10.6%   60,893  0.000137  0.000000  0.039199
enq: TX - index contention       3.069491    3.9%      137  0.022405  0.000105  0.040529
buffer busy waits                1.493510    1.9%    1,826  0.000818  0.000001  0.031146
reliable message                 0.653565    0.8%      148  0.004416  0.000215  0.036889
FETCH                            0.535304    0.7%   44,868  0.000012  0.000000  0.000895
latch: cache buffers chains      0.320590    0.4%      109  0.002941  0.000001  0.021072
DLM cross inst call completion   0.286908    0.4%      320  0.000897  0.000000  0.035637
enq: SQ - contention             0.254433    0.3%      165  0.001542  0.000105  0.003494
30 others                        1.444645    1.8%   93,031  0.000016  0.000000  0.039940
------------------------------  ---------  ------  -------  --------  --------  --------
TOTAL (40)                      78.929582  100.0%  231,963  0.000340  0.000000  0.675610
```

In this case, using Level 12 added very little overhead - the number of EXEC calls differed by only 6. There is also only a very small difference in EXEC calls.

Next, a rather high load was put on the database, to see how the cost of tracing might escalate.

### 0 Seconds Think Time

Let's consider the tests that were run with no think time.

The first thing noticed is that the number of transactions per test is about 116 times more than tests with 0.5 second think time.

The Oracle database was being pushed quite hard by these tests, maxing out the capacity of the server.

When tracing was enabled, whether at level 8 or level 12 (with bind values), there is quite a large discrepancy in the number of transactions performed.

Trace  Levels and Transaction  Counts


| Level  | Test #1 | Test #2 | Test #3 |
| ------ | ------- | ------- | ------- |
|   0    | 7,157,228 | 6,758,097 | 6,948,090 |
|   8    | 4,529,157 | 4,195,232 | 4,509,073 |
|  12    | 4,509,640 | 4,126,749 | 4,532,872 |


The number of transactions decreased by ~ 40% whenever tracing was enabled.

The high cost of enabling Oracle tracing should not be a surprise in this set to tests.  As with previous tests, the tracing level made little difference in the output. 

There was no spare capacity on the server, so any extra tasks, such as writing trace files, was going to come at the expense of other processes.

Does this mean that if a database system is overloaded, Oracle tracing should not be used?

No. What it does mean is that you should be careful about how tracing is used.

This test intentionally overloaded the database server, and then added more work by enabling Oracle trace on all 50 sessions.

In real life, it would be much better to choose only a few sessions to trace on such a busy database, perhaps even just one session, without bind values, so a start can be made on learning where the performance problems lie.

Why start with level 8 (no bind values)?

Because you probably do not know just how many placeholders appear in the SQL.

In the previous test, only a few placeholders appear in the SQL.

Each set of bind values causes (( 5 * number of placeholders ) + 2) lines to be written to the trace file.

For a set of 4 bind values, that would be 22 lines.

If there were 200 bind values, then there would 1002 more lines written to the trace file, which would make a signficant difference in the time required to write trace file.

Once you know it is safe to do so, you can dump bind values to trace if needed.

Here is a mrskew report for one set of the Level 8 tests:

```text
$ mrskew --rc=cull-snmfc.rc  trace-overhead-no-think-time/trace/trace-8-20230920123320/*.trc
CALL-NAME                           DURATION       %       CALLS      MEAN       MIN       MAX
-----------------------------  -------------  ------  ----------  --------  --------  --------
SQL*Net message from client    12,581.726556   47.9%   5,661,876  0.002222  0.000068  0.201148
log file sync                   9,838.477278   37.4%     980,400  0.010035  0.000167  8.109759
buffer busy waits               1,360.903841    5.2%     276,513  0.004922  0.000000  3.682007
enq: TX - index contention        504.928985    1.9%      69,517  0.007263  0.000005  0.708188
library cache: mutex X            401.022833    1.5%      16,665  0.024064  0.000002  0.315565
EXEC                              400.345960    1.5%   4,530,663  0.000088  0.000000  0.046535
latch: ges resource hash list     351.866071    1.3%      93,299  0.003771  0.000000  0.113945
latch: cache buffers chains       193.510957    0.7%      38,729  0.004997  0.000001  0.090246
latch: enqueue hash chains        188.572075    0.7%      55,370  0.003406  0.000001  0.123281
latch free                        118.285486    0.4%      34,727  0.003406  0.000000  0.128214
43 others                         352.240751    1.3%  10,231,718  0.000034  0.000000  3.680735
-----------------------------  -------------  ------  ----------  --------  --------  --------
TOTAL (53)                     26,291.880793  100.0%  21,989,477  0.001196  0.000000  8.109759
```

And here is Level 12

```text
$ mrskew --rc=cull-snmfc.rc  trace-overhead-no-think-time/trace/trace-12-20230920131238/*.trc
CALL-NAME                           DURATION       %       CALLS      MEAN       MIN       MAX
-----------------------------  -------------  ------  ----------  --------  --------  --------
SQL*Net message from client    12,514.788817   48.6%   5,637,406  0.002220  0.000067  0.235348
log file sync                   9,648.342333   37.5%     981,468  0.009831  0.000001  2.341050
buffer busy waits               1,210.492085    4.7%     257,119  0.004708  0.000000  0.154998
enq: TX - index contention        551.819642    2.1%      72,614  0.007599  0.000006  0.614945
EXEC                              385.670903    1.5%   4,511,120  0.000085  0.000000  0.039221
library cache: mutex X            345.251766    1.3%      16,277  0.021211  0.000004  0.269818
latch: ges resource hash list     342.435248    1.3%      92,393  0.003706  0.000000  0.118340
latch: enqueue hash chains        183.029179    0.7%      54,804  0.003340  0.000000  0.096840
latch: cache buffers chains       171.021518    0.7%      35,512  0.004816  0.000000  0.106109
latch free                        119.340511    0.5%      35,118  0.003398  0.000001  0.071759
42 others                         258.500239    1.0%  10,189,551  0.000025  0.000000  0.639226
-----------------------------  -------------  ------  ----------  --------  --------  --------
TOTAL (52)                     25,730.692241  100.0%  21,883,382  0.001176  0.000000  2.341050
```

The dominant wait in each these tests is `SQL*Net message from client`, simply due to the large number of calls that SELECT or INSERT a single row.

The Level 12 trace has only about 4% more overhead than the level 8 trace.  More on this later.


## 6 Millisecond think time.

Let's choose a value for think time that allows sufficient time for writing the trace file.

How many transactions per second could the database maintain in the previous test with 0 seconds think time?

Test #1 had the highest number of transactions at 7,157,228 total transactions.

Total runtime for 50 clients was 600 seconds each, or something very close to 600 seconds.

This works out to approximately 4.2 ms per transaction without tracing.

milliseconds / ( transaction count / ( 50 sessions * 600 seconds )) = 4.19156 ms per transaction

1000 / (7,157,228 / ( 50 * 600))

How much time is required to write to the trace file?  

We can get that by running strace on a test session that is running a level 12 trace.

The `lib/Sqlrun.pm` Perl modules was modified to wait for user input after the database connection was made, and tracing was enabled, but before the testing was started.

Doing it this way allowed checking `/proc/PID/fd` of the test session to see the File Descriptor and name of each file opened:


```text
l-wx------ 1 root root 64 Sep 18 11:40 1 -> /dev/null
lrwx------ 1 root root 64 Sep 18 11:40 10 -> socket:[113916942]
l-wx------ 1 root root 64 Sep 18 11:40 11 -> /u01/app/oracle/diag/rdbms/cdb/cdb2/trace/cdb2_ora_6237_TRC-OVRHD-12-20230918144006.trc
l-wx------ 1 root root 64 Sep 18 11:40 12 -> /u01/app/oracle/diag/rdbms/cdb/cdb2/trace/cdb2_ora_6237_TRC-OVRHD-12-20230918144006.trm
l-wx------ 1 root root 64 Sep 18 11:40 2 -> /dev/null
lrwx------ 1 root root 64 Sep 18 11:40 21 -> socket:[113914997]
lr-x------ 1 root root 64 Sep 18 11:40 3 -> /dev/null
lrwx------ 1 root root 64 Sep 18 11:40 4 -> anon_inode:[eventpoll]
lr-x------ 1 root root 64 Sep 18 11:40 5 -> /proc/6237/fd
lrwx------ 1 root root 64 Sep 18 11:40 6 -> socket:[113916934]
lr-x------ 1 root root 64 Sep 18 11:40 7 -> /u01/app/oracle/product/19.0.0/dbhome_1/rdbms/mesg/oraus.msb
lrwx------ 1 root root 64 Sep 18 11:40 8 -> anon_inode:[eventpoll]
lrwx------ 1 root root 64 Sep 18 11:40 9 -> socket:[113916941]
```

The two files of interest are `/u01/app/oracle/diag/rdbms/cdb/cdb2/trace/cdb2_ora_6237_TRC-OVRHD-12-20230918144006.tr[cm]`

These are FD 11 and 12.

So now strace is started as root for PID 6237:

  `strace -uoracle -p $pid -T -ttt -f -o trace/pid-6237.strace`

Back to sqlrun: ENTER is pressed, and now just wait for the test to finish.

Get the trace file and sum up the time spent writing to file descriptors 11 and 12.

As it turns out, knowing the file descriptors was not actually necessary, as the only OS files written to were the Oracle trace files.

We can see that because the number of all writes matches the number of writes to FD 11 and 12:

```text
$   grep -E 'write\([11|12]' trace/pid-6237.strace | wc -
1991736 

$   grep -E 'write\(' trace/pid-6237.strace | wc -l
1991736
```
The write times are seen in this summary of the trace file by [strace-breakdown.pl](https://github.com/jkstill/profilers/blob/master/strace/strace-breakdown.pl)

```text
$  ./strace-breakdown.pl <  trace/pid-6237.strace

  Total Counted Time: 1165.91173999967
  Total Elapsed Time: 1218.10785794258
Unaccounted for Time: 52.1961179429084

                      Call       Count          Elapsed                Min             Max          Avg
                    gettid           2           0.000006         0.000003        0.000003        0.000003
                       brk           2           0.000008         0.000004        0.000004        0.000004
                 getrlimit           4           0.000012         0.000003        0.000003        0.000003
                  mprotect           2           0.000013         0.000006        0.000007        0.000007
                     uname           3           0.000015         0.000004        0.000006        0.000005
                setsockopt           5           0.000019         0.000003        0.000005        0.000004
                getsockopt           6           0.000021         0.000003        0.000005        0.000004
                 epoll_ctl           7           0.000025         0.000003        0.000005        0.000004
                     chown           8           0.000054         0.000005        0.000010        0.000007
              rt_sigaction          22           0.000074         0.000003        0.000011        0.000003
                     fcntl          22           0.000074         0.000003        0.000007        0.000003
            rt_sigprocmask          20           0.000077         0.000003        0.000020        0.000004
                     fstat           1           0.000089         0.000089        0.000089        0.000089
                   geteuid          42           0.000126         0.000003        0.000003        0.000003
                     lstat          21           0.000135         0.000003        0.000031        0.000006
                      open          34           0.000174         0.000003        0.000014        0.000005
                      stat          56           0.000207         0.000003        0.000008        0.000004
                     close          32           0.000378         0.000003        0.000068        0.000012
                    semctl          15           0.001109         0.000015        0.000260        0.000074
                    munmap          24           0.001127         0.000008        0.000099        0.000047
                      mmap         104           0.001809         0.000005        0.000156        0.000017
                     shmdt           5           0.002062         0.000007        0.001878        0.000412
                   recvmsg        3220           0.021909         0.000003        0.000257        0.000007
                   sendmsg        2529           0.090821         0.000008        0.000918        0.000036
                epoll_wait        2035           0.167436         0.000003        0.001321        0.000082
                     ioctl         534           0.359921         0.000009        0.065599        0.000674
                 getrusage      108898           0.726873         0.000002        0.006818        0.000007
                     semop       13702           0.877790         0.000003        0.001226        0.000064
                     lseek      969033           5.195529         0.000002        0.007086        0.000005
                     write     1991736          12.496773         0.000002        0.010083        0.000006
                semtimedop       14161          15.281141         0.000004        0.109176        0.001079
                      read       53844        1130.685933         0.000003       20.464132        0.020999
```

On average, each write to the trace file consumes 6 microseconds, with a maximum time of 10 milliseconds.

A think time of 6 ms is roughly 1.5x the average transaction time, and should allow for maximizing the number transactions, without pushing the server so hard that runqueus get too long, and resource starvation sets in.

So the same tests were run again, but this time with `--exec-delay 0.006`.

Here we can see how the database fared at this rate, without and with tracing.

Trace  Levels and Transaction  Counts


| Level |   test 1  | test 2    |   test 3  |     Avg    | Per Second | Pct Decrease |
| ---   |   ---     |  ---      |    ---    |     ---    |  ----      | -----------  |
| 0     | 3,884,741 | 3,758,124 | 3,533,573 |  3,725,479 |    124.2   | 0 |
| 8     | 3,342,845 | 3,356,797 | 3,176,763 |  3,292,135 |    109.7   | 11.6 |
| 12    | 3,234,030 | 3,190,312 | 3,000,312 |  3,141,551 |    104.7   | 15.7 |


While the peak transaction count of 3,884,741 is only about 54% of the transaction rate for the 0 second think time test, this test is a much more reasonable approximation of a rather busy database.

The test parameter of setting a 6 ms think time will allow for some overhead, such as backups of the archive logs and database, and some other normal processing.

With Level 8 tracing, will users notice the 11.6% change in response time? It may not be all that noticeable.

Even with Level 12 tracing, an overhead of 15.7% may be tolerable for a period of time.


Again, let's see a summary of the trace files from both a Level 8 and Level 12 test.

Level 8:

```text
$ mrskew --rc=cull-snmfc.rc  trace-overhead-6ms-think-time/trace/trace-8-20230922134443/*.trc
CALL-NAME                           DURATION       %       CALLS      MEAN       MIN       MAX
-----------------------------  -------------  ------  ----------  --------  --------  --------
SQL*Net message from client    23,349.402048   80.6%   4,178,816  0.005588  0.000076  0.897703
log file sync                   4,770.140432   16.5%     781,599  0.006103  0.000001  1.467388
EXEC                              348.967653    1.2%   3,344,203  0.000104  0.000000  0.037502
enq: TX - index contention        302.733657    1.0%      13,056  0.023187  0.000007  0.768567
db file sequential read            40.958026    0.1%       7,495  0.005465  0.000194  1.456375
buffer busy waits                  39.544771    0.1%      43,642  0.000906  0.000000  0.037842
FETCH                              29.626422    0.1%   2,507,379  0.000012  0.000000  0.002080
latch: ges resource hash list      12.839064    0.0%      12,882  0.000997  0.000000  0.019123
read by other session              11.840345    0.0%         318  0.037234  0.000109  0.725882
library cache: mutex X              9.860030    0.0%       2,148  0.004590  0.000003  0.037839
41 others                          38.610023    0.1%   5,045,359  0.000008  0.000000  0.264603
-----------------------------  -------------  ------  ----------  --------  --------  --------
TOTAL (51)                     28,954.522471  100.0%  15,936,897  0.001817  0.000000  1.467388
```

Level 12:

```text
$ mrskew --rc=cull-snmfc.rc  trace-overhead-6ms-think-time/trace/trace-12-20230922135525/*.trc
CALL-NAME                           DURATION       %       CALLS      MEAN       MIN       MAX
-----------------------------  -------------  ------  ----------  --------  --------  --------
SQL*Net message from client    22,734.891709   78.5%   4,042,810  0.005624  0.000075  0.096900
log file sync                   5,495.080378   19.0%     753,598  0.007292  0.000001  3.784414
EXEC                              338.382339    1.2%   3,235,392  0.000105  0.000000  0.039067
enq: TX - index contention        214.584393    0.7%      11,310  0.018973  0.000008  0.686723
buffer busy waits                  45.639044    0.2%      42,989  0.001062  0.000000  0.240321
db file sequential read            31.671235    0.1%       5,896  0.005372  0.000205  0.730405
FETCH                              27.233206    0.1%   2,425,754  0.000011  0.000000  0.003481
latch: ges resource hash list      14.484754    0.0%      13,369  0.001083  0.000001  0.023182
log file switch completion         12.803378    0.0%         217  0.059002  0.000987  0.241770
library cache: mutex X             10.028905    0.0%       2,106  0.004762  0.000002  0.046082
41 others                          47.762738    0.2%   4,882,286  0.000010  0.000000  0.478157
-----------------------------  -------------  ------  ----------  --------  --------  --------
TOTAL (51)                     28,972.562079  100.0%  15,415,727  0.001879  0.000000  3.784414
```

Again, the modest number of SQL placeholders used did not really cause much a of time penalty when a Level 12 trace was run.


## In Conclusion

Is there any reason to be afraid of enabling Oracle tracing?

No, not really.

The key to successfully using Oracle tracing in a production environment is to first make sure you know the database where tracing is to be enabled.

If the system is quite busy, it may be necessary to first trace a single session to get a measurement of the overhead.

If you need bind values included, you can then try a Level 12 trace, and see if the number of bind values results in excessively large trace files.

Once you know what level of tracing is safe to use, you are well on your way to understanding the SQL performance problem that just landed on your desk.


