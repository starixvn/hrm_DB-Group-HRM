/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SyncEPA_Employee_Get] 
	@FromDate DATETIME = NULL
	,@CompanyId INT
AS
/*
	Created: 21102022@Tim.Trinh
	Task: get employee
	DB: HRM
	Original: 

	Revisions:
		- 20250818@Henry.Dinh: migrate data transfer feature id: #233310 
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF (@FromDate IS NOT NULL)
	BEGIN
		SELECT @FromDate = DATEADD(HH, - 1, @FromDate)
	END

	SELECT CASE WHEN ce.OldEmpId IS NOT NULL THEN ce.OldEmpId ELSE ce.EmpId END AS EmpId
		,e.UserId
		,e.[Password]
		,ce.Code
		,ce.NickName
		,e.FullName
		,ce.EmployeeCard
		,ce.DomainUsername
		,e.Phone
		,ce.Email
		,CASE WHEN ld.OldId IS NOT NULL THEN ld.OldId ELSE ld.Id END  as JobTitleId
		,ce.[Enabled] AS IsEnabled
		,ISNULL(ce.isDeleted, 0) AS IsDeleted
		,e.JoinedDate
		,e.ConfirmedDate
		,es.IsLocal
		,CASE WHEN g.OldGroupId IS NOT NULL THEN g.OldGroupId ELSE g.GroupId END AS TeamId
		,CASE 
			WHEN ce.ModifiedDate IS NULL THEN ce.CreatedDate
			ELSE ce.ModifiedDate
			END AS ModifiedDate
		,es.Unit AS CostCenter
		,ce.JobLevelId
		,e.MilitaryFromDate
		,e.MilitaryToDate
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.UserId = e.UserId AND ce.CompanyId = @CompanyId 
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = ce.GroupId AND g.CompanyId = @CompanyId
		LEFT JOIN dbo.LookupData AS ld WITH (NOLOCK) ON ld.Id = ce.JobTitleId AND ld.CompanyId = @CompanyId
	WHERE @FromDate IS NULL
		OR ce.ModifiedDate > @FromDate
		OR ce.CreatedDate > @FromDate
	ORDER BY EmpId --e.ModifiedDate--
END