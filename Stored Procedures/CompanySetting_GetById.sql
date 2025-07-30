/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CompanySetting_GetById]
	@CompanyId INT
AS
/*
    Created: 20250717@Lilac.Nguyen
    Task: Get Company by CompanyId
    DB: bodb_HRM

    Revisions:
		20250730@Lilac.Nguyen: count employee by company id
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @cols NVARCHAR(MAX);
    DECLARE @sql NVARCHAR(MAX);

    SELECT @cols = STRING_AGG(QUOTENAME([Key]), ',')
    FROM (
        SELECT DISTINCT [Key]
        FROM dbo.SystemConfigs
        WHERE [Key] <> 'CompanyId'
    ) AS KeysList;

    SET @sql = '
    SELECT 
        c.CompanyId,
        c.[Name],
        ' + @cols + '
    FROM dbo.Company c
    LEFT JOIN (
        SELECT CompanyId, ' + @cols + '
        FROM (
            SELECT CompanyId, [Key], [Value]
            FROM dbo.SystemConfigs
        ) AS SourceData
        PIVOT (
            MAX([Value]) FOR [Key] IN (' + @cols + ')
        ) AS PivotedData
    ) AS cfg ON c.CompanyId = cfg.CompanyId
    WHERE ISNULL(c.IsDeleted, 0) = 0
      AND c.CompanyId = @CompanyId';

    EXEC sp_executesql @sql, N'@CompanyId INT', @CompanyId;

	SELECT CompanyId, SubCompanyId, COUNT(*) AS EmployeeCount 
	FROM CompanyEmployee WITH (NOLOCK)
	WHERE CompanyId = @CompanyId 
	  AND ISNULL(IsDeleted, 0) <> 1
	  AND SubCompanyId IS NOT NULL
	GROUP BY CompanyId, SubCompanyId

END;