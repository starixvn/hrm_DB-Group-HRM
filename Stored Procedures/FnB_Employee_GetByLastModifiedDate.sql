/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[FnB_Employee_GetByLastModifiedDate] 
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
AS
/*
	Created: 20140320@Quinn.Vo
	Task: Get all employee from change date
	DB: NexEPA
	Original: 
	Revisions:
		- 20250813@Henry.Dinh: migrate data transfer feature id: #233310 
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ce.UserId
		,e.[Password]
		,ce.Code
		,ce.NickName
		,e.FullName
		,ce.EmployeeCard
		,ce.DomainUsername AS DomainName
		,e.Phone
		,ce.Email
		,CASE WHEN ld.OldId IS NOT NULL THEN ld.OldId ELSE ld.Id END  as JobTitleId
		,ce.[Enabled]
		,ISNULL(ce.isDeleted, 0) AS IsDeleted
		,e.JoinedDate
		,e.ConfirmedDate
		,es.IsLocal
		,g.GroupId AS TeamId
		,CASE 
			WHEN ce.ModifiedDate IS NULL THEN ce.CreatedDate
			ELSE ce.ModifiedDate
			END AS ModifiedDate
		,es.Unit AS CostCenter
		,ce.JobLevelId
		,ce.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.UserId = e.UserId
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON ce.EmpId = es.EmpId
		LEFT JOIN dbo.LookupData AS ld WITH (NOLOCK) ON ld.Id = ce.JobTitleId AND ld.CompanyId = @CompanyId
		LEFT JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = ce.GroupId AND g.CompanyId = @CompanyId
	WHERE ce.CompanyId = @CompanyId AND
		(@LastModifiedDate IS NULL
		OR ce.ModifiedDate > @LastModifiedDate
		OR ce.CreatedDate > @LastModifiedDate)
	ORDER BY ce.ModifiedDate
END