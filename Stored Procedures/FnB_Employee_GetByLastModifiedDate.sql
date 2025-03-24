/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[FnB_Employee_GetByLastModifiedDate] 
	@CompanyId SMALLINT,
	@LastModifiedDate DATETIME
AS
/*
Created: 20140320@Quinn.Vo
Task: Get all employee from change date
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
		,CASE 
			WHEN OldEmpId IS NULL THEN e.EmpId
			ELSE OldEmpId
		END AS EmpId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
	WHERE ce.CompanyId = @CompanyId
		AND @LastModifiedDate IS NULL
		OR e.ModifiedDate > @LastModifiedDate
		OR e.CreatedDate > @LastModifiedDate
	ORDER BY e.ModifiedDate
END