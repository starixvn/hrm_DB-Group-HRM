/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


CREATE PROCEDURE [dbo].[SyncEPA_EmployeeSupervisor_Get] @FromDate DATETIME = NULL
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

	SELECT DISTINCT r.[OwnerId]
		,r.[EmpId]
		,ISNULL(r.[IsDeleted], 0) AS IsDeleted
		,m.ModifiedDate AS ModifiedDate
	FROM (
		SELECT [OwnerId]
			,[EmpId]
			,ISNULL([IsDeleted], 0) AS IsDeleted
			,MAX(ModifiedDate) AS ModifiedDate
		FROM dbo.[EmployeeSupervisor] WITH (NOLOCK)
		WHERE ActionType IN (2, 3)
			AND (
				@FromDate IS NULL
				OR ModifiedDate > @FromDate
				)
		GROUP BY [OwnerId]
			,[EmpId]
			,[IsDeleted]
		) AS m
		INNER JOIN dbo.[EmployeeSupervisor] AS r WITH (NOLOCK) ON r.OwnerId = m.OwnerId
		AND r.EmpId = m.EmpId
		AND r.ModifiedDate = m.ModifiedDate
		AND r.IsDeleted = m.IsDeleted
END







