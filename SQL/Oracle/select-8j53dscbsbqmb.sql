
SELECT H.* FROM HOLIDAY H WHERE ( H."Clinic" = 0 OR H."Clinic" = (SELECT C."Clinic" FROM CHAIR C WHERE C."Chair" = :1)) AND H."StartDate" <= :2 AND H."EndDate" >= :2 AND H."PartialDay" = 0 ORDER BY H."Id" DESC

