select make, model
from ev_models
where make = :1
	and model = :2
