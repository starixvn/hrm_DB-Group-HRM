/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_Insert_CheckExist] @Nickname NVARCHAR(20)
	,@Code VARCHAR(20)
AS
/*
Created: 20250306@Tim
Task: check code, nickname available
DB: HRM
Original:

Revisions:
    20250306@Tim: initial - [Redmine: #217976]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EmpId_exist INT
		,@Nickname_exist NVARCHAR(20)
		,@FullName_exist NVARCHAR(50)

	SELECT TOP 1 @EmpId_exist = EmpId
		,@FullName_exist = FullName
		,@Nickname_exist = Nickname
	FROM dbo.Employee WITH (NOLOCK)
	WHERE Code = @Code

	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT 1 AS [Code]
			,N'Code ' + @Code + ' has been assigned' AS [Message]

		RETURN
	END

	SELECT TOP 1 @EmpId_exist = EmpId
		,@FullName_exist = FullName
		,@Nickname_exist = Nickname
	FROM dbo.Employee WITH (NOLOCK)
	WHERE NickName = @Nickname
		AND (
			isDeleted = 0
			OR [Enabled] = 1
			)

	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT 2 AS [Code]
			,N'Nickname  ' + @Nickname_exist + '  has been assigned to ' + @FullName_exist AS [Message]

		RETURN
	END

    SELECT 0 AS [Code], NULL AS [Message]
END