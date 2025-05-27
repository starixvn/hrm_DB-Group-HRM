/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_Insert] @Code VARCHAR(20)
	,@Name VARCHAR(150)
	,@CreatedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
	,@GroupTeamId INT
	,@PICEmpId INT
	,@DepartmentId INT
	,@AccountableArea VARCHAR(200) = NULL
AS
/*
Created: 20190515@Oliver.Dang
Task: insert group 
DB: HRM_SMS
Original:

Revisions:
        - 20250422@Jay: Apply create group team logic [Redmine: #221567]
        - 20250526@Jay: Allow having the same code [Redmine: #228323]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

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
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_Update] @TeamId INT
	,@Code VARCHAR(20)
	,@Name NVARCHAR(150)
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@PICEmpId INT
	,@DepartmentId INT
	,@AccountableArea VARCHAR(200) = NULL
	,@GroupTeamId INT
	,@MailGroup VARCHAR(50) = ''
	,@LocalBasicAnnualLeaveBalance TINYINT = NULL
	,@LocalWorkingDays TINYINT = NULL
	,@LocalWorkingHours TINYINT = NULL
	,@LocalOffDaysbyWeek TINYINT = NULL
	,@LocalWorkingHoursByWeek TINYINT = NULL
	,@LocalYearsOfServiceForExtraLeave INT = NULL
	,@ExpatBasicAnnualLeaveBalance TINYINT = NULL
	,@ExpatWorkingDays TINYINT = NULL
	,@ExpatWorkingHours TINYINT = NULL
	,@ExpatOffDaysbyWeek TINYINT = NULL
	,@ExpatWorkingHoursByWeek TINYINT = NULL
	,@ExpatYearsOfServiceForExtraLeave INT = NULL
AS
/*
Created: Tom.Vo@2013-10-23
Task: Update group 
DB: HRM_SMS
Original:

Revisions:
	- 20250515@Jay: add years of service for extra leave [Redmine: #227166]
	- 20250526@Jay: Allow having the same code [Redmine: #228323]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

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
				,MailGroup AS '@MailGroup'
				,LocalBasicAnnualLeaveBalance AS '@LocalBasicAnnualLeaveBalance'
				,LocalWorkingDays AS '@LocalWorkingDays'
				,LocalWorkingHours AS '@LocalWorkingHours'
				,LocalOffDaysbyWeek AS '@LocalOffDaysbyWeek'
				,LocalWorkingHoursByWeek AS '@LocalWorkingHoursByWeek'
				,LocalYearsOfServiceForExtraLeave AS '@LocalYearsOfServiceForExtraLeave'
				,ExpatBasicAnnualLeaveBalance AS '@ExpatBasicAnnualLeaveBalance'
				,ExpatWorkingDays AS '@ExpatWorkingDays'
				,ExpatWorkingHours AS '@ExpatWorkingHours'
				,ExpatOffDaysbyWeek AS '@ExpatOffDaysbyWeek'
				,ExpatWorkingHoursByWeek AS '@ExpatWorkingHoursByWeek'
				,ExpatYearsOfServiceForExtraLeave AS '@ExpatYearsOfServiceForExtraLeave'
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
		,LocalBasicAnnualLeaveBalance = @LocalBasicAnnualLeaveBalance
		,LocalWorkingDays = @LocalWorkingDays
		,LocalWorkingHours = @LocalWorkingHours
		,LocalOffDaysbyWeek = @LocalOffDaysbyWeek
		,LocalWorkingHoursByWeek = @LocalWorkingHoursByWeek
		,LocalYearsOfServiceForExtraLeave = @LocalYearsOfServiceForExtraLeave
		,ExpatBasicAnnualLeaveBalance = @ExpatBasicAnnualLeaveBalance
		,ExpatWorkingDays = @ExpatWorkingDays
		,ExpatWorkingHours = @ExpatWorkingHours
		,ExpatOffDaysbyWeek = @ExpatOffDaysbyWeek
		,ExpatWorkingHoursByWeek = @ExpatWorkingHoursByWeek
		,ExpatYearsOfServiceForExtraLeave = @ExpatYearsOfServiceForExtraLeave
		,[MailGroup] = @MailGroup
	WHERE GroupId = @TeamId

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,PICEmpId as '@PICEmpId'
				,DepartmentId as '@DepartmentId'
				,AccountableArea as '@AccountableArea'
				,GroupTeamId as '@GroupTeamId'
				,MailGroup AS '@MailGroup'
				,LocalBasicAnnualLeaveBalance AS '@LocalBasicAnnualLeaveBalance'
				,LocalWorkingDays AS '@LocalWorkingDays'
				,LocalWorkingHours AS '@LocalWorkingHours'
				,LocalOffDaysbyWeek AS '@LocalOffDaysbyWeek'
				,LocalWorkingHoursByWeek AS '@LocalWorkingHoursByWeek'
				,LocalYearsOfServiceForExtraLeave AS '@LocalYearsOfServiceForExtraLeave'
				,ExpatBasicAnnualLeaveBalance AS '@ExpatBasicAnnualLeaveBalance'
				,ExpatWorkingDays AS '@ExpatWorkingDays'
				,ExpatWorkingHours AS '@ExpatWorkingHours'
				,ExpatOffDaysbyWeek AS '@ExpatOffDaysbyWeek'
				,ExpatWorkingHoursByWeek AS '@ExpatWorkingHoursByWeek'
				,ExpatYearsOfServiceForExtraLeave AS '@ExpatYearsOfServiceForExtraLeave'
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
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Department_Update] @DepartmentId INT
	,@Code VARCHAR(20)
	,@Name VARCHAR(100)
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
Task: get department by id
DB: HRM
Original: 

Revisions:  
	- 20250421@Mira: edit Deparment - new structure [Redmine: #221568]
    - 20250526@Jay: Allow having the same code [Redmine: #228323]

Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.Department WITH (NOLOCK)
			WHERE GroupDeptId = @GroupDeptId 
				AND DepartmentId <> @DepartmentId AND IsDeleted = 0
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'Department ID ' + CONVERT(NVARCHAR(10), @GroupDeptId) + ' has already exists'

		RETURN
	END

	UPDATE dbo.Department WITH (ROWLOCK, UPDLOCK)
	SET [Code] = @Code
		,[Name] = @Name
		,[UnitId] = @UnitId
		,[IsActive] = @IsActive
		,[GroupDeptId] = @GroupDeptId
		,[AccountableArea] = @AccountableArea
		,[PICEmpId] = @PICEmpId
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = GETDATE()
	WHERE DepartmentId = @DepartmentId
END
GO