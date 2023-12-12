select
        o.owner
        , o.object_id
        , s.status
        , s.temporary
        , s.generated
from xp_object_id o
join xp_object_status s
on s.object_id = o.object_id
