/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE dbo.[Report_HRA_Get] @Year INT

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
		SELECT
			t.EmpId,
			t.UserId,
			t.Nickname,
			CASE 
				WHEN t.UnitName <> '' AND t.UnitName = t.DepartmentName
					THEN t.UnitName
				WHEN t.UnitName <> '' 
					THEN t.UnitName + ' ' + t.DepartmentName
				ELSE c.[Name]
			END 'Unit',
			c.[Name] 'Company',
			ct.CountryName 'Country',
			ct.LocationCode,
			t.JoinedDate,
			t.ConfirmedDate,
			t.ResignedDate,
			t.IsLocal			
		FROM tmpEmployeeInfo t
		LEFT JOIN Company c WITH(NOLOCK) on c.CompanyId = t.CompanyId
		LEFT JOIN Country ct WITH(NOLOCK) on ct.CountryCode = c.CountryCode
		WHERE (t.ResignedDate IS NULL OR t.ResignedDate >= @FromDate) AND
			t.IsSpecialUser = 0;
	END