CREATE OR REPLACE FUNCTION API_TimeRecord_Get(FromDate TIMESTAMP, ToDate TIMESTAMP)
RETURNS TABLE (EmpNo VARCHAR(255), InOutType VARCHAR(20), RecordTime TIMESTAMP)
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY

	SELECT att.attr_value4 as EmpNo, att_tran.att_state AS InOutType, att_tran.att_datetime AS RecordTime
		--, p.last_name as Nickname, p.name, p.name_spell
	FROM pers_person AS p
	    INNER JOIN pers_attribute_ext AS att on p.id = att.person_id
	    INNER JOIN att_transaction AS att_tran on p.pin = att_tran.pers_person_pin
	WHERE att_tran.att_datetime BETWEEN FromDate AND ToDate
	ORDER BY att_tran.att_datetime DESC;
END;
$$;