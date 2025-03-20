/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


CREATE PROCEDURE [dbo].[SyncEPA_Employee_Get] @FromDate DATETIME = NULL
AS
/*
Created: 21102022@Tim.Trinh
Task: get employee
DB: HRM
Original: 

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF (@FromDate IS NOT NULL)
	BEGIN
		SELECT @FromDate = DATEADD(HH, - 1, @FromDate)
	END

	SELECT e.EmpId
		,e.UserId
		,e.[Password]
		,e.Code
		,e.NickName
		,e.FullName
		,e.EmployeeCard
		,e.DomainUsername
		,e.Phone
		,e.Email
		,e.JobTitleId
		,e.[Enabled] AS IsEnabled
		,ISNULL(e.isDeleted, 0) AS IsDeleted
		,e.JoinedDate
		,e.ConfirmedDate
		,es.IsLocal
		,e.GroupId AS TeamId
		,CASE 
			WHEN e.ModifiedDate IS NULL THEN e.CreatedDate
			ELSE e.ModifiedDate
			END AS ModifiedDate
		,es.Unit AS CostCenter
		,e.JobLevelId
		,es.MilitaryFromDate
		,es.MilitaryToDate
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
	WHERE @FromDate IS NULL
		OR e.ModifiedDate > @FromDate
		OR e.CreatedDate > @FromDate
	ORDER BY e.ModifiedDate
END




