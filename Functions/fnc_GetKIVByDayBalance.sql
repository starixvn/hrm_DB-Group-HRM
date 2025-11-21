/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="1"></info>*/

ALTER FUNCTION [dbo].[fnc_GetKIVByDayBalance] (
	@EmpID INT
	,@Date DATETIME
	,@RequestId BIGINT = NULL
	)
RETURNS NUMERIC(18, 2)
/*
	Created:
	Task: get KIV Hour balance
	DB: bodb_HRM

	Revisions:
*/
AS
BEGIN
	DECLARE @KIVBalance NUMERIC(18, 2) = 0

	SELECT @KIVBalance = SUM(ISNULL(CreditDays, 0)) - SUM(CASE 
				WHEN @RequestId IS NULL THEN ISNULL(DeductDays, 0)
				ELSE CASE 
						WHEN RequestId = @RequestId THEN 0
						ELSE ISNULL(DeductDays, 0)
						END
				END)
	FROM dbo.KeepInViewByDayTrans WITH (NOLOCK)
	WHERE EmpId = @EmpID
		AND InYear = YEAR(@Date)

	RETURN ISNULL(@KIVBalance, 0)
END



