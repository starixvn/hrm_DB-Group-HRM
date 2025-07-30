/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE dbo.[Report_HeadcountGet] @Year INT

/*
Created: 20250219@Mira
Task : Group HRA report
DB: bodb_HRM	

Revisions:
	20250219@Mira: Get data for HRA report - [Redmine: #179302]
	20250730@Mira: Get local, expat for HRA report - [Redmine: #234522]
*/

AS
    BEGIN
        SET NOCOUNT ON;
		DECLARE @FromDate DATETIME = DATEFROMPARTS(@Year, 1, 1);

		-- select all employee haven't resigned.
		;WITH ActiveOrResignedEmployees AS (
		SELECT 	
			e.EmpId,
			e.UserId,
			e.Nickname,
			ce.CompanyId,
			ce.SubCompanyId,
			ce.CompanyDate,
			d.GroupId,
			g.DepartmentId,
			safeDates.JoinedDate,
			safeDates.ConfirmedDate,
			safeDates.ResignedDate,
			CASE
				WHEN e.EmpId IN (6081, 6596) THEN 0 -- Sean, Yves nexcel
				ELSE ISNULL(es.IsLocal, 1) 
			END AS IsLocal
		FROM dbo.Employee e WITH(NOLOCK)
		INNER JOIN dbo.CompanyEmployee ce WITH(NOLOCK) ON ce.EmpId = e.EmpId AND (ce.IsSpecialUser IS NULL OR ce.IsSpecialUser = 0)
		OUTER APPLY (
			SELECT GroupId = COALESCE(ce.GroupId, e.GroupId)
		) AS d
		INNER JOIN dbo.[Group] g WITH(NOLOCK) ON g.GroupId = d.GroupId AND g.IsOutsource = 0
		LEFT JOIN dbo.EmployeeSummary es WITH(NOLOCK) ON es.EmpId = e.EmpId AND (es.IsTopManager IS NULL OR es.IsTopManager = 0)
		OUTER APPLY (
			SELECT
				JoinedDate = CASE 
					WHEN ce.CompanyDate >= '1900-01-01' AND ce.CompanyDate <= '2079-06-06' THEN ce.CompanyDate
					WHEN e.JoinedDate >= '1900-01-01' AND e.JoinedDate <= '2079-06-06' THEN e.JoinedDate
					ELSE '1990-01-01'
				END,
				ConfirmedDate = CASE 
					WHEN ce.ConfirmedDate >= '1900-01-01' AND ce.ConfirmedDate <= '2079-06-06' THEN ce.ConfirmedDate
					WHEN e.ConfirmedDate >= '1900-01-01' AND e.ConfirmedDate <= '2079-06-06' THEN e.ConfirmedDate
					ELSE '1990-01-01'
				END,
				ResignedDate = CASE 
					WHEN ce.ResignedDate >= '1900-01-01' AND ce.ResignedDate <= '2079-06-06' THEN ce.ResignedDate
					WHEN e.ResignedDate >= '1900-01-01' AND e.ResignedDate <= '2079-06-06' THEN e.ResignedDate
					ELSE NULL
				END
		) AS safeDates
		WHERE
			(
				safeDates.ResignedDate >= @FromDate
				OR (safeDates.ResignedDate IS NULL AND ISNULL(ce.Enabled, e.Enabled) = 1)
			)
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
		ISNULL(CAST(ct.CountryCodeISO3 AS VARCHAR(10)), 'Other') AS CountryCode,
		e.JoinedDate,
		e.ConfirmedDate,
		e.ResignedDate,
		e.IsLocal
	FROM ActiveOrResignedEmployees e
	LEFT JOIN dbo.Company c WITH(NOLOCK) ON c.CompanyId = e.CompanyId
	LEFT JOIN dbo.SubCompany sub WITH(NOLOCK) ON sub.SubCompanyId = e.SubCompanyId
	LEFT JOIN dbo.Country ct WITH(NOLOCK) ON ct.CountryCode = c.CountryCode
	INNER JOIN dbo.Department d WITH(NOLOCK) ON d.DepartmentId = e.DepartmentId
	INNER JOIN dbo.Unit unit WITH(NOLOCK) ON unit.UnitId = d.UnitId;
END