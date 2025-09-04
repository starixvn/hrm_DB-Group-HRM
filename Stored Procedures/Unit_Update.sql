/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Unit_Update]
(
	@UnitId INT
	,@Code VARCHAR(20)
	,@Name VARCHAR(100)
	,@GroupUnitId INT
	,@PICEmpId INT = NULL
	,@Category VARCHAR(150) = ''
	,@Type VARCHAR(150) = ''
	,@AccountableArea VARCHAR(150) = ''
	,@IsActive BIT = NULL
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
	,@SupporterEmpId INT = NULL
)
AS
/*
	Created: 20200521@Patsy.Doan
	Task: Update Unit.
	DB: HRM

	Revisions:
		- 20250410@Henry: remove company_id + update field [Redmine: #221569]
		- 20250903@Jay: update role [Redmine: #237201]
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
		SELECT 1
		FROM dbo.Unit WITH (NOLOCK)
		WHERE GroupUnitId = @GroupUnitId
			AND UnitId <> @UnitId
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
			AND UnitId <> @UnitId
			AND IsDeleted = 0
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Business Unit code ' + @Code + ' has already exists'

		RETURN
	END

	UPDATE dbo.Unit WITH (ROWLOCK, UPDLOCK)
	SET [Code] = @Code
		,[Name] = @Name
		,[GroupUnitId] = @GroupUnitId
		,[PICEmpId] = @PICEmpId
		,[SupporterEmpId] = @SupporterEmpId
		,[Category] = @Category
		,[Type] = @Type
		,[AccountableArea] = @AccountableArea
		,[IsActive] = @IsActive
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = GETDATE()
	WHERE UnitId = @UnitId
END