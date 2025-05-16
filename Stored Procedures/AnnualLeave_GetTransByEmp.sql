/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_GetTransByEmp] @EmpId INT
	,@fromDate DATETIME
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

	DECLARE @fromdateRange DATETIME
		,@todateRange DATETIME

	SELECT @fromdateRange = FromDate
		,@todateRange = ISNULL(ToDate, DATEADD(YEAR, 1, DATEADD(YEAR, DATEDIFF(YEAR, 0, FromDate), 0)))
	FROM (
		SELECT 
			FromDate,
			ToDate,
			ROW_NUMBER() OVER (ORDER BY FromDate ASC) AS rn
		FROM dbo.LeaveTrans WITH (NOLOCK)
		WHERE EmpId = @EmpId
			AND FromDate <= @fromDate
			AND ToDate > @fromDate
			AND CreditDays > 0
			AND RequestId IS NULL
			AND ISNULL(Deleted, 0) = 0
	) AS t
	WHERE rn = 1


	SELECT t.LeaveTransId
		,RequestId
		,FromDate AS AffectedFrom
		,ISNULL(CreditDays, 0) - ISNULL(DeductDays, 0) AS [ToTalDays]
		,[Description]
		,ISNULL(t.ModifiedDate, t.CreatedDate) AS ModifiedDate
	FROM dbo.LeaveTrans t WITH (NOLOCK)
		INNER JOIN dbo.Employee e WITH (NOLOCK) ON e.EmpID = t.EmpId
	WHERE fromdate >= @fromdateRange
		AND fromdate < @todateRange
		AND ISNULL(ExtraDays, 0) = 0
		AND t.EmpId = @EmpId
		AND ISNULL(Deleted, 0) = 0
		AND (
			@excludedRequestTrans = 0
			OR RequestId IS NULL
			)
END