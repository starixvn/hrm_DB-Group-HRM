/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


CREATE PROCEDURE [dbo].[SyncEPA_Employee_Get] 
	@FromDate DATETIME = NULL
	,@CompanyId INT
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

	SELECT CASE WHEN e.OldEmpId IS NOT NULL THEN e.OldEmpId ELSE e.EmpId END AS EmpId
		,e.UserId
		,e.[Password]
		,e.Code
		,e.NickName
		,e.FullName
		,e.EmployeeCard
		,e.DomainUsername
		,e.Phone
		,e.Email
		,CASE WHEN ld.OldId IS NOT NULL THEN ld.OldId ELSE ld.Id END  as JobTitleId
		,e.[Enabled] AS IsEnabled
		,ISNULL(e.isDeleted, 0) AS IsDeleted
		,e.JoinedDate
		,e.ConfirmedDate
		,es.IsLocal
		,CASE WHEN g.OldGroupId IS NOT NULL THEN g.OldGroupId ELSE g.GroupId END AS TeamId
		,CASE 
			WHEN e.ModifiedDate IS NULL THEN e.CreatedDate
			ELSE e.ModifiedDate
			END AS ModifiedDate
		,es.Unit AS CostCenter
		,e.JobLevelId
		,es.MilitaryFromDate
		,es.MilitaryToDate
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId AND ce.CompanyId = @CompanyId 
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = e.GroupId AND g.CompanyId = @CompanyId
		LEFT JOIN dbo.LookupData AS ld WITH (NOLOCK) ON ld.Id = e.JobTitleId AND ld.CompanyId = @CompanyId
	WHERE @FromDate IS NULL
		OR e.ModifiedDate > @FromDate
		OR e.CreatedDate > @FromDate
	ORDER BY EmpId --e.ModifiedDate--
END



