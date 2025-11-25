/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_HeadcountGet] @Year INT
/*
    Created: 20250219@Mira
    Task : Group HRA report
    DB: bodb_HRM	

    Revisions:
	    20250219@Mira: Get data for HRA report - [Redmine: #179302]
	    20250730@Mira: Get local, expat for HRA report - [Redmine: #234522]
	    20250815@Mira: Exclude empty CtrId - [Redmine: #236138]
	    20250814@Lilac: restructure for transfer [Redmine: #235678]
	    20250821@Mira: Exclude special user NexHRM - [Redmine: #236138]
	    20250828@Mira: restructure for transfer [Redmine: #235678]
	    20251001@Mira: correct SP [Redmine: #240215]
	    20251014@Mira: exclude employee of deleted group [Redmine: #240215]
		20251027@Mira: get employee transfer - [Redmine: #242668]
		20251030@Mira: correct confirmDate [Redmine: #242636]
		20251120@Mira: only get GroupDate [Redmine: #244781]
*/
AS
    BEGIN
        SET NOCOUNT ON;
		DECLARE @FromDate DATETIME = DATEFROMPARTS(@Year, 1, 1);
		DECLARE @NexcelId TINYINT = 1, @LumiId TINYINT = 2,  @NexVisionId TINYINT = 34

		-- select all employee haven't resigned.
		;WITH ActiveOrResignedEmployees AS (
		SELECT 	
			ce.EmpId,
			e.UserId,
			ce.Nickname,
			ce.CompanyId,
			ce.SubCompanyId,
			ce.CompanyDate,
			d.GroupId,
			g.DepartmentId,
			safeDates.JoinedDate,
			safeDates.ConfirmedDate,
			safeDates.ResignedDate,
			ce.Enabled,
			CASE
				WHEN ce.EmpId IN (6081, 6596) THEN 0 -- Sean, Yves nexcel
				ELSE ISNULL(es.IsLocal, 1) 
			END AS IsLocal
		FROM dbo.Employee AS e WITH(NOLOCK)
		    INNER JOIN dbo.CompanyEmployee AS ce WITH(NOLOCK) ON ce.UserId = e.UserId AND (ce.CompanyId NOT IN (@NexcelId, @LumiId, @NexVisionId) OR ce.IsSpecialUser = 0)
		    OUTER APPLY (
			    SELECT GroupId = ce.GroupId
		    ) AS d
		    INNER JOIN dbo.[Group] AS g WITH(NOLOCK) ON g.GroupId = d.GroupId AND g.IsOutsource = 0 AND g.IsDeleted = 0
		    LEFT JOIN dbo.EmployeeSummary AS es WITH(NOLOCK) ON es.EmpId = ce.EmpId
		    OUTER APPLY (
			    SELECT
				    JoinedDate = CASE 
					    WHEN e.JoinedDate >= '1900-01-01' AND e.JoinedDate <= '2079-06-06' THEN e.JoinedDate
					    ELSE '1990-01-01'
				    END,
				    ConfirmedDate = CASE 
					    WHEN e.ConfirmedDate >= '1900-01-01' AND e.ConfirmedDate <= '2079-06-06' THEN e.ConfirmedDate
					    ELSE NULL
				    END,
				    ResignedDate = CASE 
					    WHEN e.ResignedDate >= '1900-01-01' AND e.ResignedDate <= '2079-06-06' THEN e.ResignedDate
					    ELSE NULL
				    END
		    ) AS safeDates
			LEFT JOIN dbo.EmployeeTransfer AS et WITH(NOLOCK) ON et.FromEmpId = ce.EmpId
		WHERE
			(
				e.CtrId IS NOT NULL AND (
					safeDates.ResignedDate >= @FromDate OR -- be active emp
					(safeDates.ResignedDate IS NULL AND ce.Enabled = 1) OR -- Exclude inactive emp
					(safeDates.ResignedDate IS NULL AND ce.Enabled = 0 AND et.TransferId IS NOT NULL) -- Get info Transfer Out
				)
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
		CASE 
			WHEN secondCountry.CountryCodeISO3 IS NOT NULL THEN secondCountry.CountryCodeISO3
			ELSE ISNULL(CAST(ct.CountryCodeISO3 AS VARCHAR(10)), 'Other')
		END AS CountryCode,
		e.JoinedDate,
		e.ConfirmedDate,
		e.ResignedDate,
		e.IsLocal,
		e.Enabled
	FROM ActiveOrResignedEmployees AS e
	    LEFT JOIN dbo.Company AS c WITH(NOLOCK) ON c.CompanyId = e.CompanyId
	    LEFT JOIN dbo.SubCompany AS sub WITH(NOLOCK) ON sub.SubCompanyId = e.SubCompanyId
	    LEFT JOIN dbo.Country AS ct WITH(NOLOCK) ON ct.CountryCode = c.CountryCode
	    LEFT JOIN dbo.Department AS d WITH(NOLOCK) ON d.DepartmentId = e.DepartmentId
	    LEFT JOIN dbo.Unit AS unit WITH(NOLOCK) ON unit.UnitId = d.UnitId
		LEFT JOIN dbo.CompanySecondmentEmployee AS secondEmp WITH(NOLOCK) ON secondEmp.EmpId = e.EmpId
		LEFT JOIN dbo.Company AS secondComp WITH(NOLOCK) ON secondComp.CompanyId = secondEmp.CompanyId
		LEFT JOIN dbo.Country AS secondCountry WITH(NOLOCK) ON secondCountry.CountryCode = secondComp.CountryCode;
END