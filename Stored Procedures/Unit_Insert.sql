/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Unit_Insert] 
(	@Code VARCHAR(20)
	,@Name VARCHAR(100)
	,@GroupUnitId INT
	,@PICEmpId INT = NULL
	,@Category VARCHAR(150) = ''
	,@Type VARCHAR(150) = ''
	,@AccountableArea VARCHAR(150) = ''
	,@IsActive BIT = 1
	,@CreatedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
	Created: 20200521@Patsy.Doan
	Task: Insert Unit.
	DB: HRM

	Revisions:
		- 20250410@Henry: remove company_id + update field [Redmine: #221569]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
		SELECT 1
		FROM dbo.Unit WITH (NOLOCK)
		WHERE GroupUnitId = @GroupUnitId
            AND IsDeleted = 0
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Business Unit ID ' + CAST(@GroupUnitId AS NVARCHAR(10)) + ' has already exists'

		RETURN
	END

	IF EXISTS (
		SELECT 1
		FROM dbo.Unit WITH (NOLOCK)
		WHERE Code = @Code
            AND IsDeleted = 0
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Business Unit code ' + @Code + ' has already exists'

		RETURN
	END

	INSERT INTO dbo.Unit(
		[Code]
		,[Name]
		,[GroupUnitId]
		,[PICEmpId]
		,[Category]
		,[Type]
		,[AccountableArea]
		,[ModifiedBy]
		,[ModifiedDate]
		,[IsActive]
		,[IsDeleted]
		)
	VALUES (
		@Code
		,@Name
		,@GroupUnitId
		,@PICEmpId
		,@Category
		,@Type
		,@AccountableArea
		,@CreatedBy
		,GETDATE()
		,@IsActive
		,0
		)
END