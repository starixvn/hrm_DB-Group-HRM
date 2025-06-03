/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER    PROCEDURE [dbo].[FnB_Employee_GetSecondmentCompany] 
	@CompanyId SMALLINT
AS
/*
Created: Hank.Nguyen@2025-05-27
Task: Get all secondment employees from change date
DB: NexEPA
Original: 

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT e.UserId
		,e.[Password]
		,e.Code
		,e.NickName
		,e.FullName
		,e.EmployeeCard
		,e.DomainUsername AS DomainName
		,e.Phone
		,e.Email
		,e.[Enabled]
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
		,e.EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.CompanySecondmentEmployee AS cs WITH (NOLOCK) ON cs.EmpId = e.EmpId
	WHERE cs.CompanyId = @CompanyId 
	ORDER BY e.ModifiedDate
END