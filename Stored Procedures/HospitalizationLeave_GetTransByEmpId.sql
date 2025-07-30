/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[HospitalizationLeave_GetTransByEmpId] @EmpId INT
	,@Year INT
	,@IncludedRequestTrans BIT = 0
AS
/*
Created: Tim.Trinh@2021-08-20
Task: get hospitalization leave transaction by employee
DB: HRM
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromdate DATETIME
		,@todate DATETIME

	SET @fromdate = CAST(@year AS VARCHAR(10)) + '/01/01'
	SET @todate = dateadd(YEAR, 1, @fromdate)

	SELECT t.TransId
		,t.RequestId
		,FromDate AS AffectedFrom
		,ISNULL(t.CreditDays, 0) - ISNULL(t.DeductDays, 0) AS TotalDays
		,t.[Description]
		,ISNULL(t.ModifiedDate, t.CreatedDate) AS ModifiedDate
	FROM dbo.HospitalizationLeaveTrans AS t WITH (NOLOCK)
	WHERE t.FromDate >= @fromdate
		AND t.FromDate < @todate
		AND t.EmpId = @EmpId
		AND t.IsDeleted = 0
		AND (
			@IncludedRequestTrans = 1
			OR RequestId IS NULL
			)
END


