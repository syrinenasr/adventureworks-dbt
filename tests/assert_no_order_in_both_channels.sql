-- Internet and reseller sales are separate order streams. An order number
-- that shows up in both channels would mean the union mixed them up.

select sales_order_number
from {{ ref('fct_sales') }}
group by sales_order_number
having count(distinct channel) > 1
