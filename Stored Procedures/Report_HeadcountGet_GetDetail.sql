/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_HeadcountGet_GetDetail]
(
    @EmpIds VARCHAR(MAX) = ''
)
AS
/*
	Created: 20251030@Mira
	Task: get employees in headcount report 
	DB: bodb_HRM

	Revisions:
        20251030@Mira: get employees in headcount report [Redmine: #242636]
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpEmp(EmpId INT PRIMARY KEY);

	INSERT INTO #tmpEmp(EmpId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@EmpIds, ',');
	
	SELECT 
		e.CtrId,
		ce.EmpId,
		ce.Code,
		ce.Nickname, 
		e.FullName,
		e.Gender,
		e.DOB,
		ce.[Enabled],
		ce.isDeleted,
		e.JoinedDate,
		e.ResignedDate, 
		e.ConfirmedDate,
		s.IsLocal,
		ce.IsSpecialUser,
		ce.CompanyDate, 
		c.[Name] AS Company, 
		sub.Name AS SubCompany,
		CAST(u.GroupUnitId AS VARCHAR(10)) + ' - ' + u.Code AS BU,
		g.[Name] AS TeamName, 
		d.[Name] AS DepartmentName, 
		CASE 
			WHEN secondCountry.CountryCodeISO3 IS NOT NULL THEN secondCountry.CountryCodeISO3
			ELSE ISNULL(CAST(ct.CountryCodeISO3 AS VARCHAR(10)), 'Other')
		END AS [Location]
	FROM #tmpEmp t
		INNER JOIN dbo.CompanyEmployee ce WITH (NOLOCK) ON ce.EmpId = t.EmpId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupID = g.GroupID
		INNER JOIN dbo.[Department] AS d WITH (NOLOCK) ON d.DepartmentId = g.DepartmentId
		INNER JOIN dbo.[Unit] AS u WITH (NOLOCK) ON d.UnitId = u.UnitId
		LEFT JOIN dbo.EmployeeSummary AS s WITH (NOLOCK) ON s.EmpId = ce.EmpId
		LEFT JOIN dbo.SubCompany AS sub WITH (NOLOCK) ON sub.SubCompanyId = ce.SubCompanyId
		LEFT JOIN dbo.Country AS ct WITH (NOLOCK) ON ct.CountryCode = c.CountryCode
		LEFT JOIN dbo.CompanySecondmentEmployee AS secondEmp WITH(NOLOCK) ON secondEmp.EmpId = ce.EmpId
		LEFT JOIN dbo.Company AS secondComp WITH(NOLOCK) ON secondComp.CompanyId = secondEmp.CompanyId
		LEFT JOIN dbo.Country AS secondCountry WITH(NOLOCK) ON secondCountry.CountryCode = secondComp.CountryCode;
END;