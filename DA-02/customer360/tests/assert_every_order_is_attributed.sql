-- Every CRM order must have at least one touchpoint (its own purchase session).
select o.order_id
from {{ ref('stg_crm__orders') }} as o
left join (select distinct order_id from {{ ref('fct_attribution') }}) as a
    on o.order_id = a.order_id
where a.order_id is null
