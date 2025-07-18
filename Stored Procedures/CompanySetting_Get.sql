/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[CompanySetting_Get]
AS

/*
Created: 20250717@Lilac.Nguyen
Task: Get Setting Companys
DB: bodb_HRM
Original:

Revisions:

*/

BEGIN
    SET NOCOUNT ON;

    DECLARE @cols NVARCHAR(MAX);
    DECLARE @sql NVARCHAR(MAX);

	SELECT @cols = STRING_AGG(QUOTENAME([Key]), ',')
	FROM (
		SELECT DISTINCT [Key]
		FROM dbo.SystemConfigs
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
	ORDER BY c.CompanyId;
	';

	EXEC sp_executesql @sql;

END;

