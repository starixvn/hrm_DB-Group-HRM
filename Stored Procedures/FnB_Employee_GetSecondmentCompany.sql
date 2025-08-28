/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[FnB_Employee_GetSecondmentCompany] 
	@CompanyId SMALLINT
AS
/*
	Created: Hank.Nguyen@2025-05-27
	Task: Get all secondment employees from change date
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
		,ce.[Enabled]
		,ISNULL(ce.isDeleted, 0) AS IsDeleted
		,e.JoinedDate
		,e.ConfirmedDate
		,es.IsLocal
		,ce.GroupId AS TeamId
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
		INNER JOIN dbo.CompanySecondmentEmployee AS cs WITH (NOLOCK) ON cs.EmpId = ce.EmpId
	WHERE cs.CompanyId = @CompanyId 
	ORDER BY ce.ModifiedDate
END