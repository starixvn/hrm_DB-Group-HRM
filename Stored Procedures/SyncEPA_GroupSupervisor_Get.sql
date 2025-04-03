/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/


CREATE PROCEDURE [dbo].[SyncEPA_GroupSupervisor_Get] @FromDate DATETIME = NULL
		,@CompanyId INT
AS
/*
Created: 20150921@Quinn.Vo
Task: Get all group supervisor from change date
DB: NexEPA
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF(@FromDate IS NOT NULL)
	BEGIN
		SELECT @FromDate = DATEADD(HH, -1, @FromDate)
	END

	SELECT DISTINCT CASE WHEN e.OldEmpId IS NOT NULL THEN e.OldEmpId ELSE e.EmpId END AS OwnerId
		,CASE WHEN g.OldGroupId IS NOT NULL THEN g.OldGroupId ELSE g.GroupId END AS GroupId
		,m.[ModifiedDate]
		,ISNULL(r.[IsDeleted], 0) AS IsDeleted
	FROM (
		SELECT OwnerId
			,GroupId
			,MAX(ModifiedDate) AS ModifiedDate
		FROM dbo.GroupSupervisor WITH (NOLOCK)
		WHERE ActionType IN (2, 3)
			AND (
				@FromDate IS NULL
				OR ModifiedDate > @FromDate
				)
		GROUP BY OwnerId
			,GroupId
		) AS m
		INNER JOIN dbo.[GroupSupervisor] r WITH (NOLOCK) ON r.OwnerId = m.OwnerId
		AND r.GroupId = m.GroupId
		AND r.ModifiedDate = m.ModifiedDate
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON g.GroupId = r.GroupId AND g.CompanyId = @CompanyId
		LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = r.OwnerId
		WHERE m.OwnerId > 0
		ORDER BY OwnerId, GroupId
END












