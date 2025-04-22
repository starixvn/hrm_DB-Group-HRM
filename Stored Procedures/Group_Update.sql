/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_Update] @TeamId INT
	,@Code VARCHAR(20)
	,@Name NVARCHAR(150)
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@PICEmpId INT
	,@DepartmentId INT
	,@AccountableArea VARCHAR(200)
	,@GroupTeamId INT
AS
/*
Created: Tom.Vo@2013-10-23
Task: Update group 
DB: HRM_SMS
Original:

Revisions:
	- 20250422@Jay: Apply gupdate group team logic [Redmine: #221567]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId <> @TeamId
				AND Code = @code
				AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Code "' + @code + '" have been used by other group.'

		RETURN
	END

	IF EXISTS (
			SELECT 1
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId <> @TeamId 
				AND GroupTeamId = @GroupTeamId
				AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Team Id "' + CAST(@GroupTeamId AS NVARCHAR) + '" have been used by other group.'

		RETURN
	END

	DECLARE @xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,PICEmpId AS '@PICEmpId'
				,DepartmentId AS '@DepartmentId'
				,AccountableArea AS '@AccountTableArea'
				,GroupTeamId AS '@GroupTeamId'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @TeamId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	UPDATE dbo.[Group] WITH (ROWLOCK, UPDLOCK)
	SET Code = @Code
		,[Name] = @Name
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
		,PICEmpId = @PICEmpId
		,DepartmentId = @DepartmentId
		,AccountableArea = @AccountableArea
		,GroupTeamId = @GroupTeamId
	WHERE GroupId = @TeamId

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,PICEmpId as '@PICEmpId'
				,DepartmentId as '@DepartmentId'
				,AccountableArea as '@AccountableArea'
				,GroupTeamId as '@GroupTeamId'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @TeamId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 2
		,@ObjectId = @TeamId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END