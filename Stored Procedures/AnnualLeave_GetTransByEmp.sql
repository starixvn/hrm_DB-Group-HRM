/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_GetTransByEmp] @EmpId INT
	,@Year INT
	,@excludedRequestTrans BIT
AS
/*
Created: Tom.Vo@2013.10.22
Task: show annual leave tranasaction by employee
DB: HRM
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromdate DATETIME
		,@todate DATETIME

	SET @fromdate = cast(@year AS VARCHAR(4)) + '/01/01'
	SET @todate = dateadd(yy, 1, @fromdate)

	SELECT t.LeaveTransId
		,RequestId
		,FromDate AS AffectedFrom
		,ISNULL(CreditDays, 0) - ISNULL(DeductDays, 0) AS [ToTalDays]
		,[Description]
		,ISNULL(t.ModifiedDate, t.CreatedDate) AS ModifiedDate
	FROM dbo.LeaveTrans t WITH (NOLOCK)
		INNER JOIN dbo.Employee e WITH (NOLOCK) ON e.EmpID = t.EmpId
	WHERE fromdate >= @fromdate
		AND fromdate < @todate
		AND t.EmpId = @EmpId
		AND ISNULL(Deleted, 0) = 0
		AND (
			@excludedRequestTrans = 0
			OR RequestId IS NULL
			)
END