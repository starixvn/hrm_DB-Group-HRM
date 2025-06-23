/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE dbo.[Report_HeadcountGet] @Year INT

/*
Created: 20250219@Mira
Task : Group HRA report
DB: bodb_HRM	

Revisions:
	20250219@Mira: Get data for HRA report - [Redmine: #179302]
*/

AS
    BEGIN
        SET NOCOUNT ON;
		DECLARE @FromDate DATETIME = DATEFROMPARTS(@Year, 1, 1);

		-- select all employee haven't resigned.
		;WITH ActiveOrResignedEmployees AS (
			SELECT e.*, g.DepartmentId
			FROM dbo.Employee e WITH(NOLOCK) 
			INNER JOIN dbo.[Group] g WITH(NOLOCK) ON g.GroupId = e.GroupId
			INNER JOIN dbo.EmployeeSummary es WITH(NOLOCK) ON es.EmpId = e.EmpId
			WHERE g.IsOutsource = 0 -- exclude the Outsource team 
				AND (
					ResignedDate >= @FromDate
					OR (ResignedDate IS NULL AND Enabled = 1)
				)
				AND es.IsTopManager = 0
		)
		SELECT
			e.EmpId,
			e.UserId,
			e.Nickname,
			unit.Code AS Unit,
			CASE 
				WHEN unit.Category = 'Product' 
					THEN unit.Category + ' (' + ISNULL(unit.Type, '') + ')'
				ELSE unit.Category
			END AS UnitCategory,
			ISNULL(sub.Name, c.Name) AS Company,
			CASE 
				WHEN ISNULL(sub.Name, c.Name) IN ('WGI', 'BPO', 'SRM', 'EXT', 'OSEAS', NULL, '') THEN 'OTHER'
				ELSE ct.CountryName
			END AS Country,
			ISNULL(CAST(ct.CountryCodeISO3 AS VARCHAR(10)), 'WFH') AS CountryCode,
			e.JoinedDate,
			e.ConfirmedDate,
			e.ResignedDate
		FROM ActiveOrResignedEmployees e
		INNER JOIN dbo.CompanyEmployee ce WITH(NOLOCK) ON ce.EmpId = e.EmpId
		LEFT JOIN dbo.Company c WITH(NOLOCK) ON c.CompanyId = ce.CompanyId
		LEFT JOIN dbo.Country ct WITH(NOLOCK) ON ct.CountryCode = c.CountryCode
		LEFT JOIN dbo.SubCompany sub WITH(NOLOCK) ON sub.SubCompanyId = ce.SubCompanyId
		INNER JOIN dbo.Department d WITH(NOLOCK) ON d.DepartmentId = e.DepartmentId
		INNER JOIN dbo.Unit unit WITH(NOLOCK) ON unit.UnitId = d.UnitId;
	END