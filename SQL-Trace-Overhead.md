
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

==>> NOTE: Be sure to create and populate this branch in the Pythian Git Repo.

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

See [create-csv.sh]( PUT PYTHIAN REPO URL FOR FILE HERE)

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

The estimate f 60,000 did not account for any overhead, and so was optimistic.  It was not expected that 60k transactions would be reached.

At this rate, there are ~ 100 transactions per second being performed on the database.

Trace  Levels and Transaction  Counts


| Level  | Test #1 | Test #2 | Test #3 |
| ------ | ------- | ------- | ------- |
|   0    | 59386   | 59454   | 59476   |
|   8    | 59415   | 59365   | 59334   |
|  12    | 59411   | 59177   | 59200   |


The difference between tracing and not tracing would not be discernable by users.


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

This should not be a surprise in this set to tests.

The tracing level made little difference in the output. 

There was no spare capacity on the server, so any extra tasks, such as writing trace files, was going to come at the expense of other processes.

Does this mean that if a database system is overloaded, Oracle tracing should not be used?

No. What it does mean is that you should be careful about how tracing is used.

This test intentionally overloaed the database server, and then added more work by enabling Oracle trace on all 50 sessions.

In real life, it would be much better to choose only a few sessions to trace, perhaps even just one session, without bind values, so a start can be made on learning where the performance problems lie.

Why start with level 8 (no bind values)?

Because you probably do not know just how many placeholders appear in the SQL.

In the previous test, only a few placeholders appear in the SQL.

Each set of bind values causes (( 5 * number of placeholders ) + 2) lines to be written to the trace file.

For a set of 4 bind values, that would be 22 lines.

If there were 200 bind values, then there would 1002 more lines written to the trace file, which would make a signficant difference in the time required to write trace file.

Once you know it is safe to do so, you can dump bind values to trace if needed.


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

                      Call       Count          Elapsed                Min             Max          Avg ms
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

A think time of 6 ms should allow for maximizing the number transactions, without pushing the server so hard that runqueus get too long, and resource starvation sets in.

So the same test were run again, but this time with `--exec-delay 0.006`.

Here we can see how the database fared at this rate, without and with tracing.

Trace  Levels and Transaction  Counts


| Level |   test 1  | test 2    |   test 3  |     Avg    | Per Second | Pct Decrease |
| ---   |   ---     |  ---      |    ---    |     ---    |  ----      | -----------  |
| 0     | 3,884,741 | 3,758,124 | 3,533,573 |  3,725,479 |    124.2   | 0 |
| 8     | 3,342,845 | 3,356,797 | 3,176,763 |  3,292,135 |    109.7   | 11.6 |
| 12    | 3,234,030 | 3,190,312 | 3,000,312 |  3,141,551 |    104.7   | 15.7 |


While the peak transaction count of 3,884,741 is only about 54% of the transaction rate for the 0 second think time test, this test is a much more reasonable approximation of a rather busy database.

The test parameter of setting a 6 ms think will allow for some overhead, such as backups of the archive logs and database, and some other normal processing.

With Level 8 tracing, will users notice the 11.6% change in response time? It may not be all that noticable.

Even with Level 12 tracing, an overhead of 15.7% may be tolerable for a period of time.


## In Conclusion

Is there any reason to be afraid of enabling Oracle tracing?

No, not really.

They key is to first make sure you know the database where tracing is to be enabled.

If the system is quite busy, it may be necessary to first trace a single session to get a measurement of the overhead.

Once that is done, you will be well on your way to finding exactly where the time is going for underperforming SQL statements.










