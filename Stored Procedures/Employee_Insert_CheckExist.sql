/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_Insert_CheckExist]
(
    @CompanyId SMALLINT
    ,@Nickname NVARCHAR(20)
    ,@Code VARCHAR(20)
)
AS
/*
    Created: 20250306@Tim
    Task: check code, nickname available
    DB: bodb_HRM

    Revisions:
        20250306@Tim: initial [Redmine: #217976]
        20250819@Tim: restructure [Redmine: #235678]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EmpId_exist INT
		,@Nickname_exist NVARCHAR(20)
		,@FullName_exist NVARCHAR(50)

	SELECT TOP 1 @EmpId_exist = ce.EmpId
		,@FullName_exist = e.FullName
		,@Nickname_exist = ce.Nickname
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
        INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
	WHERE ce.Code = @Code
		AND ce.CompanyId = @CompanyId

	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT 1 AS [Code]
			,N'Code ' + @Code + ' has been assigned ' + @FullName_exist AS [Message]

		RETURN
	END

	SELECT TOP 1 @EmpId_exist = ce.EmpId
		,@FullName_exist = e.FullName
		,@Nickname_exist = ce.Nickname
	FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
        INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
	WHERE ce.Nickname = @Nickname
		AND ce.CompanyId = @CompanyId
		AND (
			ce.IsDeleted = 0
			OR ce.[Enabled] = 1
			)

	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT 2 AS [Code]
			,N'Nickname ' + @Nickname_exist + ' has been assigned to ' + @FullName_exist AS [Message]

		RETURN
	END

    SELECT 0 AS [Code], NULL AS [Message]
END