/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Group_Insert]
(
    @Code VARCHAR(20)
    ,@Name VARCHAR(150)
    ,@CreatedBy INT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg VARCHAR(200) = '' OUTPUT
    ,@CompanyId SMALLINT
    ,@GroupTeamId INT
    ,@PICEmpId INT = NULL
    ,@DepartmentId INT
    ,@AccountableArea VARCHAR(200) = NULL
	,@IsOutsource BIT = 0
)
AS
/*
    Created: 20190515@Oliver.Dang
    Task: insert group 
    DB: bodb_HRM

    Revisions:
        - 20250422@Jay: Apply create group team logic [Redmine: #221567]
        - 20250526@Jay: Allow having the same code [Redmine: #228323]
        - 20250530@Jay: allow PICEmpId be null [Redmine: #225528]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupTeamId = @GroupTeamId
				AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = N'Team Id "' + CAST(@GroupTeamId AS NVARCHAR) + '" exists.'

		RETURN
	END

	INSERT INTO dbo.[Group] (
		Code
		,[Name]
		,CreatedDate
		,CreatedBy
		,CompanyId
		,GroupTeamId
		,PICEmpId
		,DepartmentId
		,AccountableArea
		,IsOutsource
		)
	VALUES (
		@Code
		,@Name
		,GETDATE()
		,@CreatedBy
		,@CompanyId
		,@GroupTeamId
		,@PICEmpId
		,@DepartmentId
		,@AccountableArea
		,@IsOutsource
		)

	DECLARE @id INT = cast(SCOPE_IDENTITY() AS INT)

	DECLARE @xml XML
		,@logData NVARCHAR(MAX)

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,CompanyId as '@CompanyId'
				,GroupTeamId as '@GroupTeamId'
				,PICEmpId as '@PICEmpId'
				,DepartmentId as '@DepartmentId'
				,AccountableArea as '@AccountableArea'
				,IsOutsource as '@IsOutsource'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @id
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @CreatedBy
		,@ObjectTypeId = 2
		,@ObjectId = @id
		,@OldData = NULL
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END