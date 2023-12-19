
create or replace view expand_sql_test
as
select o.order_id, o.order_date,o.customer_id 
	, i.line_item_id, i.product_id
from oe.orders o
join oe.order_items i on i.order_id = o.order_id
order by o.order_id, i.line_item_id
/

@get-view 'select * from expand_sql_test' 
