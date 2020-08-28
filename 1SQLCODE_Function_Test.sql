--Create a Table to capture how many times ORA-02292 errors occurred.
CREATE TABLE tcount (x int); -- table to count the number of 2292 errors

--Parent Table
create table orders (order_id int, total_sales int);
CREATE UNIQUE INDEX orders_pk on orders (order_id);
ALTER TABLE orders ADD CONSTRAINT orders_pk PRIMARY KEY (order_id) ENABLE;

--Child Table
CREATE TABLE products
( product_id numeric(10) not null,
supplier_id numeric(10) not null,
order_id int,
CONSTRAINT fk_orders
FOREIGN KEY (order_id)
REFERENCES orders(order_id)
);

--Add data in Parent and Child Tables
insert into orders values (1,1);
insert into products values (1,1,1);
commit;

--Verify the data on those Tables
select * from orders;
select * from products;

--Create the procedure to Delete data from Parent table and force the error ORA-02292
CREATE OR REPLACE PROCEDURE delete_order
(order_id_in IN NUMBER)
IS
vtest2292 int := 0;
BEGIN
delete from orders where order_id = order_id_in;
commit;

-- if the delete instruction runs fine the tcount table is truncated
EXECUTE IMMEDIATE ('truncate table tcount');

EXCEPTION
WHEN OTHERS THEN
DECLARE
error_code NUMBER := SQLCODE;
BEGIN
IF error_code = -2292 THEN
null;
DBMS_OUTPUT.PUT_LINE('ERROR 2292!!!!!!!!!!!!!'); -- error found
insert into tcount values (1);
commit;

select count(1) into vtest2292 from tcount;

IF vtest2292 >= 2 then
DBMS_OUTPUT.PUT_LINE('ERROR 2292 >x2!!!!!!!!!!!!!!'); -- two or more consecutive errors found
raise_application_error (-20001,'Two or more ORA-2292 were occurred deleting an order.');
END IF;
ELSE
raise_application_error (-20002,'An ERROR has occurred deleting an order.');
END IF;
END;
END;
/

--Job to run the procedure delete_order and confirm that just after the second consecutive execution the error will be written in alert log
BEGIN
DBMS_SCHEDULER.create_job (
job_name => 'job_delete_order',
job_type => 'PLSQL_BLOCK',
job_action => 'begin delete_order(1); end;',
start_date => SYSTIMESTAMP,
repeat_interval => 'FREQ=HOURLY;BYMINUTE=0; interval=1;',
enabled => TRUE);
END;
/

--Running the job job_delete_order to force the error, we have to monitor the database alert log to confirm that just after two executions the error will be visible there
set serveroutput on
select count(1) from tcount;
exec dbms_scheduler.run_job('job_delete_order',FALSE);
select count(1) from tcount;

tail -f alert_database_name.log
