/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[GroupSupervisor_GetByRole]
(
    @TeamId INT
    ,@Role TINYINT
	,@CompanyId SMALLINT = NULL
)
AS
/*
    Created: 20140723@Quinn.Vo
    Task: Get list supervisors by group and action type.
    DB: bodb_HRM

    Revisions:
        - 20250730@Jay: Add company name for group filter [Redmine: #233324]
        - 20250812@Mira: tranfer employee [Redmine: #235678]
        - 20250910@Tim: fix bug get special user
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @NexcelId SMALLINT = 1, @LumiId SMALLINT = 2,  @NexVisionId SMALLINT = 34

	SELECT ce.EmpId
		,CASE 
			WHEN @CompanyId IS NOT NULL AND @CompanyId = c.CompanyId THEN ce.NickName
			ELSE ce.NickName + ' (' + ISNULL(c.Name, '') + ')'
		END AS NickName
		,e.FullName
		,g.GroupId AS TeamId
		,g.Code
		,g.Code AS TeamCode
		,g.[Name]
		,su.OwnerId
		,c.CompanyId AS CompanyId
		,c.[Name] AS CompanyName
		,CAST(MAX(CASE 
					WHEN su.RequestType IN (1, 2) THEN 1
					ELSE 0
					END) AS BIT) AS HasCheckInOut
		,CAST(MAX(CASE 
					WHEN su.RequestType IN (3, 4) THEN 1
					ELSE 0
					END) AS BIT) AS HasLateInEarlyOut
		,CAST(MAX(CASE 
					WHEN su.RequestType = 5 THEN 1
					ELSE 0
					END) AS BIT) AS HasChangeShift
		,CAST(MAX(CASE 
					WHEN su.RequestType = 6 THEN 1
					ELSE 0
					END) AS BIT) AS HasLeave
		,CAST(MAX(CASE 
					WHEN su.RequestType = 7 THEN 1
					ELSE 0
					END) AS BIT) AS HasKeepInView
		,CAST(MAX(CASE 
					WHEN su.RequestType = 8 THEN 1
					ELSE 0
					END) AS BIT) AS HasOvertime
		,CASE 
			WHEN @CompanyId IS NOT NULL AND @CompanyId = c.CompanyId THEN 1
			WHEN @CompanyId IS NULL THEN 1 -- group
			ELSE 0
		END AS CanRemove
	FROM dbo.GroupSupervisor AS su WITH (NOLOCK)
		INNER JOIN dbo.[CompanyEmployee] AS ce WITH (NOLOCK) ON ce.EmpId = su.OwnerId
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON @TeamId = g.GroupId
		INNER JOIN dbo.[Company] AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
	WHERE su.GroupId = @TeamId
        AND su.ActionType = @Role
        AND ISNULL(su.IsDeleted, 0) = 0
        AND (ce.CompanyId NOT IN (@NexcelId, @LumiId, @NexVisionId) OR ce.IsSpecialUser = 0)
        AND ISNULL(ce.IsDeleted, 0) = 0 AND ISNULL(ce.Enabled, 1) = 1
	GROUP BY ce.EmpId
        ,ce.NickName
        ,e.FullName
        ,g.GroupId
        ,g.Code
        ,g.[Name]
        ,su.DisplayOrder
        ,su.OwnerId
        ,c.[Name]
        ,c.CompanyId
	ORDER BY ISNULL(su.DisplayOrder, 0)
END