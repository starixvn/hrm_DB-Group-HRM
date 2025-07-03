/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


CREATE OR ALTER PROCEDURE [dbo].[SyncEPA_EmployeeSupervisor_Get] @FromDate DATETIME = NULL
	,@CompanyId INT 
AS
/*
Created: 20150921@Quinn.Vo
Task: Get all employee supervisor from change date
DB: NexEPA
Original: 

Revisions:  
20160428@Razor.Nguyen: new way to syn data
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF(@FromDate IS NOT NULL)
	BEGIN
		SELECT @FromDate = DATEADD(HH, -1, @FromDate)
	END

	SELECT DISTINCT CASE WHEN own.OldEmpId IS NOT NULL THEN own.OldEmpId ELSE own.EmpId END AS OwnerId
		,CASE WHEN emp.OldEmpId IS NOT NULL THEN emp.OldEmpId ELSE emp.EmpId END AS EmpId 
		,ISNULL(r.[IsDeleted], 0) AS IsDeleted
		,m.ModifiedDate AS ModifiedDate
	FROM (
		SELECT [OwnerId]
			,es.[EmpId]
			,ISNULL(es.[IsDeleted], 0) AS IsDeleted
			,MAX(ModifiedDate) AS ModifiedDate
		FROM dbo.[EmployeeSupervisor] AS es WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ec WITH (NOLOCK) ON ec.EmpId = es.EmpId AND ec.CompanyId = @CompanyId
		WHERE ActionType IN (2, 3)
			AND (
				@FromDate IS NULL
				OR ModifiedDate > @FromDate
				)
		GROUP BY [OwnerId]
			,es.[EmpId]
			,es.[IsDeleted]
		) AS m
		INNER JOIN dbo.[EmployeeSupervisor] AS r WITH (NOLOCK) ON r.OwnerId = m.OwnerId
		AND r.EmpId = m.EmpId
		AND r.ModifiedDate = m.ModifiedDate
		AND r.IsDeleted = m.IsDeleted
		LEFT JOIN dbo.Employee AS own WITH (NOLOCK) ON own.EmpId = r.OwnerId
		LEFT JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.EmpId = r.EmpId
		ORDER BY EmpId, OwnerId
END








