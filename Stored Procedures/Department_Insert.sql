/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Department_Insert] @Code VARCHAR(50)
	,@Name NVARCHAR(200)
	,@UnitId INT
	,@IsActive BIT
	,@ModifiedBy INT
	,@GroupDeptId INT
	,@AccountableArea NVARCHAR(100) = ''
	,@PICEmpId INT = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20200521@Lilac.Nguyen
Task: Insert Department
DB: HRM
Original: 

Revisions:  
	- 20250421@Mira: add new Deparment - new structure [Redmine: #221568]
	- 20250526@Jay: Allow having the same code [Redmine: #228323]

Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.Department WITH (NOLOCK)
			WHERE GroupDeptId = @GroupDeptId AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Department ID ' + CONVERT(NVARCHAR(10), @GroupDeptId) + ' has already exists'

		RETURN
	END
	
	INSERT INTO dbo.Department(
		[Code]
		,[Name]
		,[UnitId]
		,[IsActive]
		,[ModifiedBy]
		,[ModifiedDate]
		,[IsDeleted]
		,[AccountableArea]
		,[GroupDeptId]
		,[PICEmpId]
		)
	VALUES (
		@Code
		,@Name
		,@UnitId
		,@IsActive
		,@ModifiedBy
		,GETDATE()
		,0
		,@AccountableArea
		,@GroupDeptId
		,@PICEmpId
		)
END