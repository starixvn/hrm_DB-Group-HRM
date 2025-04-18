USE [bodb_IUC]
GO

DECLARE @rowIndex INT
	,@TotalRows INT
	,@Password VARCHAR(100) = '$2a$11$HlrbWdanSgkujUqWux8VneSldcHne2leIvOdsjeDQGa1CcFp6cEd2' /*123456*/
    ,@SiteId SMALLINT = 15
	,@RoleId TINYINT = 1


SELECT @RowIndex = 1
	,@TotalRows = COUNT(1)
FROM [dbo].[tmpInitUser] WITH (NOLOCK)

WHILE @RowIndex <= @TotalRows
BEGIN
   DECLARE @UserId INT

	INSERT INTO dbo.[User](Code, FullName, Nickname, [Password], [OldPassword], IsActive, IsDeleted, IsResetPassword, CreatedDate)
	SELECT Code, FullName, Nickname, @Password, @Password, 1, 0, 1, GETDATE()
	FROM [dbo].[tmpInitUser] AS tmp WITH (NOLOCK)
	WHERE RowIndex = @rowIndex
		AND NOT EXISTS (
		SELECT 1
		FROM dbo.[User] AS u WITH (NOLOCK)
		WHERE tmp.Code = u.Code
			AND tmp.Nickname = u.Nickname
		)

    IF @@ROWCOUNT > 0
	BEGIN
		SET @UserId = CAST(SCOPE_IDENTITY() AS INT)

		INSERT INTO dbo.UserSite(UserId, SiteId, IsActive)
		VALUES (@UserId, @SiteId, 1)

		INSERT INTO dbo.UserRole(UserId, SiteId, RoleId)
		VALUES (@UserId, @SiteId, @RoleId)

		INSERT INTO dbo.UserMapping(UserId, SiteId, RefId)
		VALUES (@UserId, @SiteId, @UserId)


		UPDATE dbo.[tmpInitUser] WITH (ROWLOCK, UPDLOCK)
		SET UserId = @UserId
		WHERE RowIndex = @rowIndex
	END

	SET @RowIndex = @RowIndex + 1
END




GO

SELECT 
    t.Code,
    t.FullName, 
    t.Nickname,
    t.TeamCode,
    t.TeamName,
    t.UserId as TempUserId,
    u.UserId as ActualUserId,
    CASE 
        WHEN u.UserId IS NULL THEN 'Not Created'
        ELSE 'Created'
    END as Status
FROM dbo.tmpInitUser t
LEFT JOIN dbo.[User] u ON t.Code = u.Code AND t.Nickname = u.Nickname
ORDER BY t.RowIndex;
