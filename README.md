
Expand an Oracle View to Full SELECT Text
=========================================

When working on a view that is itself composed of SELECT statements on other views, it can be difficult to know what the complete SQL text looks like.

Most of the time it may not be necessary to see the entire expanded SQL.  When trying to improve the performance of a SQL statement however, the expanded SQL can be very useful.

The following demo was created on an Oracle 19.12 database.

The client is Linux. Some of these scripts may require adjustments for the differences in how lines are terminate if the scripts are run on Windows.

These tables and views are rather contrived, and do not fit any good design pattern. They are simply for demonstration o f 

## dbms_utility.expand_sql_text

The `DBMS_UTILITY` package has a procedure `EXPAND_SQL_TEXT`. As per the documentation:

`This procedure recursively replaces any view references in the input SQL query with the corresponding view subquery.`

I will use `dbms_utility.expand_sql_text` to expand some simple SQL statements into the full SQL that is used by Oracle.


## create-tables.sql

This script just reads the `ALL_OBJECTS` view to create several smaller test tables.

```text
@@ create-tables

Table dropped.


Table dropped.


Table dropped.


Table dropped.


Table dropped.


Table dropped.


Commit complete.

TEST_OBJECTS

Table created.

XP_OBJECT_ID

Table created.

XP_OBJECT_NAMES

Table created.

XP_OBJECT_DATES

Table created.

XP_OBJECT_TYPES

Table created.

XP_OBJECT_STATUS

Table created.


Commit complete.
```

## create-views.sql

Now create some views on the new tables, as well as some views on views.


```text
@@ create-views
XP_OBJECT_ID_V

View created.

XP_OBJECT_DATES_V

View created.

XP_OBJECT_NAMES_V

View created.

XP_OBJECT_TYPES_V

View created.

XP_OBJECT_STATUS_V

View created.

XP_OBJECT_ID_TYPE_V

View created.

XP_OBJECT_ID_NAME_V

View created.

XP_OBJECT_ID_STATUS_V

View created.

XP_OBJECT_ID_DATES_V

View created.

XP_OBJECTS_V

View created.
```

## permissions

It would be best to run these script as an account that has DBA privileges, otherwise it may fail.

From OH/rdbms/admin/dbmsutil.sql

```text
   -  ORA-24256 will be raised if the current user does not have SELECT
      privileges on all the views and tables recursively referenced in the
      input sql text. It will also be raised if the user does not have
      EXECUTE privileges on all functions and types referenced from within
      views that are expanded as well as any other reason a valid query could
      not be expanded. The ORA-24256's error message text contains information
      regarding the particular restriction that wasn't satisfied.
   -  ORA-24251 will be raised if the input_sql text is not a select statement.
   -  ORA-00900 will be raised if the input is not valid.
   -  ORA-29477 will be raised if the input lob size exceeds the maximum size
      of 4GB -1.

```

## get-view.sql

Now for a demo of `dbms_utility.expand_sql_text`

Here is a simple demontration:

```text
@get-view 'select * from dual'
SELECT "A1"."DUMMY" "DUMMY" FROM "SYS"."DUAL" "A1"
SQL#
```

Now for one of the views created previously:

```text
@get-view 'select * from XP_OBJECT_ID_V'
SELECT "A1"."OWNER" "OWNER","A1"."OBJECT_ID" "OBJECT_ID" FROM  (SELECT "A2"."OWNER" "OWNER","A2"."OBJECT_ID" "OBJECT_ID" FROM "JKSTILL"."XP_OBJECT_ID" "A2") "A1"
SQL#
```

So far, so good. That view was simply a select on a single table.

Let's see what happens when 1+ views are referenced in the SQL:

```text

@get-view 'select * from XP_OBJECT_ID_TYPE_V'
SELECT "A1"."OWNER" "OWNER","A1"."OBJECT_ID" "OBJECT_ID","A1"."OBJECT_TYPE" "OBJECT_TYPE" FROM  (SELECT "A2"."QCSJ_C000000000400000_0" "OWNER","A2"."QCSJ_C000000000400002_1" "OBJECT_ID","A2"."OBJECT_TYPE_4" "OBJECT_TYPE" FROM  (SELECT "A4"."OWNER" "QCSJ_C000000000400000_0","A4"."OBJECT_ID" "QCSJ_C000000000400002_1","A3"."OWNER" "QCSJ_C000000000400001","A3"."OBJECT_ID" "QCSJ_C000000000400003","A3"."OBJECT_TYPE" "OBJECT_TYPE_4" FROM  (SELECT "A5"."OWNER" "OWNER","A5"."OBJECT_ID" "OBJECT_ID" FROM "JKSTILL"."XP_OBJECT_ID" "A5") "A4", (SELECT "A6"."OWNER" "OWNER","A6"."OBJECT_ID" "OBJECT_ID","A6"."OBJECT_TYPE" "OBJECT_TYPE" FROM "JKSTILL"."XP_OBJECT_TYPES" "A6") "A3" WHERE "A3"."OBJECT_ID"="A4"."OBJECT_ID") "A2") "A1"
#SQL
```

OK, that is rather difficult to read.

From now on the script `get-view.sh` will be used, which logs in to database, gets the expanded sql text and runs it through a formatter.

Note: you will need to change the credentials in the script if you run this yourself.

Let's try it:

```text
$  ./get-view.sh  'select * from XP_OBJECT_ID_TYPE_V' | expand -t3

SELECT
   A1.OWNER OWNER
   ,A1.OBJECT_ID OBJECT_ID
   ,A1.OBJECT_TYPE OBJECT_TYPE
FROM
(
   SELECT
      A2.QCSJ_C000000000400000_0 OWNER
      ,A2.QCSJ_C000000000400002_1 OBJECT_ID
      ,A2.OBJECT_TYPE_4 OBJECT_TYPE
   FROM
   (
      SELECT
         A4.OWNER QCSJ_C000000000400000_0
         ,A4.OBJECT_ID QCSJ_C000000000400002_1
         ,A3.OWNER QCSJ_C000000000400001
         ,A3.OBJECT_ID QCSJ_C000000000400003
         ,A3.OBJECT_TYPE OBJECT_TYPE_4
      FROM
      (
         SELECT
            A5.OWNER OWNER
            ,A5.OBJECT_ID OBJECT_ID
         FROM JKSTILL.XP_OBJECT_ID A5
      ) A4,
      (
         SELECT
            A6.OWNER OWNER
            ,A6.OBJECT_ID OBJECT_ID
            ,A6.OBJECT_TYPE OBJECT_TYPE
         FROM JKSTILL.XP_OBJECT_TYPES A6
      ) A3
      WHERE A3.OBJECT_ID=A4.OBJECT_ID
   ) A2
) A1

```

That is much easier to read.

When 1+ objects (including tables, not just views) are referenced in the SQL, Oracle creates unique column names for each referenced column:

For example:

```text

$ cat > t1.sql
$  cat >  t1.sql
select
        o.owner
        , o.object_id
        , s.status
        , s.temporary
        , s.generated
from xp_object_id o
join xp_object_status s
on s.object_id = o.object_id
^D

$  ./get-view.sh  "$(cat t1.sql | tr '\n' ' ')" | expand -t3

SELECT
   A1.QCSJ_C000000000300000_0 OWNER
   ,A1.QCSJ_C000000000300002_1 OBJECT_ID
   ,A1.STATUS_4 STATUS
   ,A1.TEMPORARY_5 TEMPORARY
   ,A1.GENERATED_6 GENERATED
FROM
(
   SELECT
      A3.OWNER QCSJ_C000000000300000_0
      ,A3.OBJECT_ID QCSJ_C000000000300002_1
      ,A2.OWNER QCSJ_C000000000300001
      ,A2.OBJECT_ID QCSJ_C000000000300003
      ,A2.STATUS STATUS_4
      ,A2.TEMPORARY TEMPORARY_5
      ,A2.GENERATED GENERATED_6
   FROM JKSTILL.XP_OBJECT_ID A3,JKSTILL.XP_OBJECT_STATUS A2 WHERE A2.OBJECT_ID=A3.OBJECT_ID
) A1

```

Why would Oracle do that? Consider the following SQL snippet from the previous output:

```text
      SELECT
         A4.OWNER QCSJ_C000000000400000_0
         ,A4.OBJECT_ID QCSJ_C000000000400002_1
         ,A3.OWNER QCSJ_C000000000400001
         ,A3.OBJECT_ID QCSJ_C000000000400003
         ,A3.OBJECT_TYPE OBJECT_TYPE_4
```

The column OBJECT_NAME appears twice, in each of the A3 and A4 inline views.  The unique names are used to disambiguate the column names.

## The Full SQL Text

There is one view that joins all other views: XP_OBJECTS_V.  Let's see what the expanded SQL looks like:

```text
$  ./get-view.sh "select * from xp_objects_v"  | expand -t3

SELECT
   A1.OWNER OWNER
   ,A1.OBJECT_ID OBJECT_ID
   ,A1.OBJECT_TYPE OBJECT_TYPE
   ,A1.OBJECT_NAME OBJECT_NAME
   ,A1.STATUS STATUS
   ,A1.CREATED CREATED
   ,A1.LAST_DDL_TIME LAST_DDL_TIME
FROM
(
   SELECT
      A2.QCSJ_C000000000400000_0 OWNER
      ,A2.QCSJ_C000000000400002_1 OBJECT_ID
      ,A2.OBJECT_TYPE_2 OBJECT_TYPE
      ,A2.OBJECT_NAME_5 OBJECT_NAME
      ,A2.STATUS_8 STATUS
      ,A2.CREATED_11 CREATED
      ,A2.LAST_DDL_TIME_12 LAST_DDL_TIME
   FROM
   (
      SELECT
         A4.QCSJ_C000000000400000_0 QCSJ_C000000000400000_0
         ,A4.QCSJ_C000000000400002_1 QCSJ_C000000000400002_1
         ,A4.OBJECT_TYPE_2 OBJECT_TYPE_2
         ,A4.QCSJ_C000000000400001_3 QCSJ_C000000000400001
         ,A4.QCSJ_C000000000400003_4 QCSJ_C000000000400003
         ,A4.OBJECT_NAME_5 OBJECT_NAME_5
         ,A4.OWNER_6 QCSJ_C000000000800000
         ,A4.OBJECT_ID_7 QCSJ_C000000000800002
         ,A4.STATUS_8 STATUS_8
         ,A3.OWNER QCSJ_C000000000800001
         ,A3.OBJECT_ID QCSJ_C000000000800003
         ,A3.CREATED CREATED_11
         ,A3.LAST_DDL_TIME LAST_DDL_TIME_12
      FROM
      (
         SELECT
            A6.QCSJ_C000000000400000_0 QCSJ_C000000000400000_0
            ,A6.QCSJ_C000000000400002_1 QCSJ_C000000000400002_1
            ,A6.OBJECT_TYPE_2 OBJECT_TYPE_2
            ,A6.QCSJ_C000000000400001_3 QCSJ_C000000000400001_3
            ,A6.QCSJ_C000000000400003_4 QCSJ_C000000000400003_4
            ,A6.OBJECT_NAME_5 OBJECT_NAME_5
            ,A5.OWNER OWNER_6
            ,A5.OBJECT_ID OBJECT_ID_7
            ,A5.STATUS STATUS_8
         FROM
         (
            SELECT
               A8.OWNER QCSJ_C000000000400000_0
               ,A8.OBJECT_ID QCSJ_C000000000400002_1
               ,A8.OBJECT_TYPE OBJECT_TYPE_2
               ,A7.OWNER QCSJ_C000000000400001_3
               ,A7.OBJECT_ID QCSJ_C000000000400003_4
               ,A7.OBJECT_NAME OBJECT_NAME_5
            FROM
            (
               SELECT
                  A9.QCSJ_C000000002600000_0 OWNER
                  ,A9.QCSJ_C000000002600002_1 OBJECT_ID
                  ,A9.OBJECT_TYPE_4 OBJECT_TYPE
               FROM
               (
                  SELECT
                     A11.OWNER QCSJ_C000000002600000_0
                     ,A11.OBJECT_ID QCSJ_C000000002600002_1
                     ,A10.OWNER QCSJ_C000000002600001
                     ,A10.OBJECT_ID QCSJ_C000000002600003
                     ,A10.OBJECT_TYPE OBJECT_TYPE_4
                  FROM
                  (
                     SELECT
                        A12.OWNER OWNER
                        ,A12.OBJECT_ID OBJECT_ID
                     FROM JKSTILL.XP_OBJECT_ID A12
                  ) A11,
                  (
                     SELECT
                        A13.OWNER OWNER
                        ,A13.OBJECT_ID OBJECT_ID
                        ,A13.OBJECT_TYPE OBJECT_TYPE
                     FROM JKSTILL.XP_OBJECT_TYPES A13
                  ) A10
                  WHERE A10.OBJECT_ID=A11.OBJECT_ID
               ) A9
            ) A8,
            (
               SELECT
                  A14.QCSJ_C000000002100000_0 OWNER
                  ,A14.QCSJ_C000000002100002_1 OBJECT_ID
                  ,A14.OBJECT_NAME_4 OBJECT_NAME
               FROM
               (
                  SELECT
                     A16.OWNER QCSJ_C000000002100000_0
                     ,A16.OBJECT_ID QCSJ_C000000002100002_1
                     ,A15.OWNER QCSJ_C000000002100001
                     ,A15.OBJECT_ID QCSJ_C000000002100003
                     ,A15.OBJECT_NAME OBJECT_NAME_4
                  FROM
                  (
                     SELECT
                        A17.OWNER OWNER
                        ,A17.OBJECT_ID OBJECT_ID
                     FROM JKSTILL.XP_OBJECT_ID A17
                  ) A16,
                  (
                     SELECT
                        A18.OWNER OWNER
                        ,A18.OBJECT_ID OBJECT_ID
                        ,A18.OBJECT_NAME OBJECT_NAME
                     FROM JKSTILL.XP_OBJECT_NAMES A18
                  ) A15
                  WHERE A15.OBJECT_ID=A16.OBJECT_ID
               ) A14
            ) A7
            WHERE A7.OBJECT_ID=A8.OBJECT_ID
         ) A6,
         (
            SELECT
               A19.QCSJ_C000000001600000_0 OWNER
               ,A19.QCSJ_C000000001600002_1 OBJECT_ID
               ,A19.STATUS_4 STATUS
               ,A19.TEMPORARY_5 TEMPORARY
               ,A19.GENERATED_6 GENERATED
            FROM
            (
               SELECT
                  A21.OWNER QCSJ_C000000001600000_0
                  ,A21.OBJECT_ID QCSJ_C000000001600002_1
                  ,A20.OWNER QCSJ_C000000001600001
                  ,A20.OBJECT_ID QCSJ_C000000001600003
                  ,A20.STATUS STATUS_4
                  ,A20.TEMPORARY TEMPORARY_5
                  ,A20.GENERATED GENERATED_6
               FROM
               (
                  SELECT
                     A22.OWNER OWNER
                     ,A22.OBJECT_ID OBJECT_ID
                  FROM JKSTILL.XP_OBJECT_ID A22
               ) A21,
               (
                  SELECT
                     A23.OWNER OWNER
                     ,A23.OBJECT_ID OBJECT_ID
                     ,A23.STATUS STATUS
                     ,A23.TEMPORARY TEMPORARY
                     ,A23.GENERATED GENERATED
                  FROM JKSTILL.XP_OBJECT_STATUS A23
               ) A20
               WHERE A20.OBJECT_ID=A21.OBJECT_ID
            ) A19
         ) A5
         WHERE A5.OBJECT_ID=A6.QCSJ_C000000000400002_1
      ) A4,
      (
         SELECT
            A24.QCSJ_C000000001100000_0 OWNER
            ,A24.QCSJ_C000000001100002_1 OBJECT_ID
            ,A24.CREATED_4 CREATED
            ,A24.LAST_DDL_TIME_5 LAST_DDL_TIME
            ,A24.TIMESTAMP_6 TIMESTAMP
         FROM
         (
            SELECT
               A26.OWNER QCSJ_C000000001100000_0
               ,A26.OBJECT_ID QCSJ_C000000001100002_1
               ,A25.OWNER QCSJ_C000000001100001
               ,A25.OBJECT_ID QCSJ_C000000001100003
               ,A25.CREATED CREATED_4
               ,A25.LAST_DDL_TIME LAST_DDL_TIME_5
               ,A25.TIMESTAMP TIMESTAMP_6
            FROM
            (
               SELECT
                  A27.OWNER OWNER
                  ,A27.OBJECT_ID OBJECT_ID
               FROM JKSTILL.XP_OBJECT_ID A27
            ) A26,
            (
               SELECT
                  A28.OWNER OWNER
                  ,A28.OBJECT_ID OBJECT_ID
                  ,A28.CREATED CREATED
                  ,A28.LAST_DDL_TIME LAST_DDL_TIME
                  ,A28.TIMESTAMP TIMESTAMP
               FROM JKSTILL.XP_OBJECT_DATES A28
            ) A25
            WHERE A25.OBJECT_ID=A26.OBJECT_ID
         ) A24
      ) A3
      WHERE A3.OBJECT_ID=A4.QCSJ_C000000000400002_1
   ) A2
) A1
```

That simple SELECT statement expanded into 196 lines of SQL!

Imagine that you have been given the task of improving the performance of `select * from xp_objects_v`.

On the surface, it looks simple. But when you start digging in to it, say by getting an execution plan or a SQL trace, you realize the SQL is much more complex than it first appeared.

The `dbms_utility.expand_sql_text` procedure can help you get a better grasp of the full SQL statement that is being executed.


