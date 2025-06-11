CREATE OR REPLACE FUNCTION API_TimeRecord_Get(FromDate TIMESTAMP, ToDate TIMESTAMP)
RETURNS TABLE (EmpNo VARCHAR(255), InOutType SMALLINT, RecordTime TIMESTAMP)
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY

	SELECT att.attr_value4 as EmpNo,
	    CASE WHEN att_tran.device_sn = 'COOA233760012' OR att_tran.device_sn = 'COOA232560014' THEN 0 ELSE 1 END::SMALLINT AS InOutType,
	    att_tran.att_datetime AS RecordTime
	    --, p.last_name as Nickname, p.name, p.name_spell
	FROM pers_person AS p
	    INNER JOIN pers_attribute_ext AS att on p.id = att.person_id
	    INNER JOIN att_transaction AS att_tran on p.pin = att_tran.pers_person_pin
	WHERE att_tran.device_sn IN ('COOA233760001', 'COOA233760010', 'COOA233760012', 'COOA232560014')
	    AND att_tran.att_datetime BETWEEN FromDate AND ToDate
	    AND COALESCE(att.attr_value4, '') != ''
	ORDER BY att_tran.att_datetime DESC;
END;
$$;