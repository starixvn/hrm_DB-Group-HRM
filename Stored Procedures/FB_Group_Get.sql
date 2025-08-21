/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[FB_Group_Get] @FromDate DATETIME = NULL
AS
/*
Created: 20140320@Quinn.Vo
Task: Get all groups from change date
DB: HRM
Original:

Revisions:
	20250821@Jay: restructure for transfer [Redmine: #235678]
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	IF @FromDate IS NOT NULL
	BEGIN
		SELECT @FromDate = DATEADD(HH, - 1, @FromDate)
	END

	SELECT g.GroupId AS TeamId
		,g.GroupTeamId
		,g.Code
		,g.[Name]
		,mng.EmpId AS LeaderId
		,g.[Rank]
		,ISNULL(g.IsDeleted, 0) AS IsDeleted
		,CASE 
			WHEN g.ModifiedDate IS NULL THEN g.CreatedDate
			ELSE g.ModifiedDate
			END AS ModifiedDate
	FROM dbo.[Group] AS g WITH (NOLOCK)
		LEFT JOIN dbo.GroupManager AS mng WITH (NOLOCK) ON g.GroupId = mng.GroupId
		AND mng.RoleId = 1 -- head
	WHERE @FromDate IS NULL
		OR ISNULL(g.ModifiedDate, g.CreatedDate) > @FromDate
	ORDER BY g.ModifiedDate
END