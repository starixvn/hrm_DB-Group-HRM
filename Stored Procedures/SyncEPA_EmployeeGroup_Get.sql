/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SyncEPA_EmployeeGroup_Get] 
(
	@CompanyId INT,
    @FromDate DATETIME = NULL
)
AS
/*
    Created: 20140320@Quinn.Vo
    Task: Get all groups from change date
    DB: bodb_HRM

    Revisions:
        20250409@Tim: remove section [Redmine: #222886]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF @FromDate IS NOT NULL
	BEGIN
		SELECT @FromDate = DATEADD(HH, - 1, @FromDate)
	END

	SELECT ISNULL(g.OldGroupId, g.GroupId) AS TeamId
		,g.DepartmentId
		,g.Code
		,g.[Name]
		,g.[Rank]
		,ISNULL(g.IsDeleted, 0) AS IsDeleted
		,CASE 
			WHEN g.ModifiedDate IS NULL THEN g.CreatedDate
			ELSE g.ModifiedDate
			END AS ModifiedDate
	FROM dbo.[Group] AS g WITH (NOLOCK)
	WHERE g.CompanyId = @CompanyId 
        AND (@FromDate IS NULL OR ISNULL(g.ModifiedDate, g.CreatedDate) > @FromDate)
	ORDER BY TeamId
END