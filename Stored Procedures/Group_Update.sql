/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Group_Update] @TeamId INT
	,@Code VARCHAR(20)
	,@Name NVARCHAR(150)
	,@MailGroup VARCHAR(50) = ''
	,@ManagerIds VARCHAR(MAX) = ''
	,@LeaderIds VARCHAR(MAX) = ''
	,@SupervisorIds VARCHAR(MAX) = ''
	,@LocalBasicAnnualLeaveBalance TINYINT = NULL
	,@LocalWorkingDays TINYINT = NULL
	,@LocalWorkingHours TINYINT = NULL
	,@LocalOffDaysbyWeek TINYINT = NULL
	,@LocalWorkingHoursByWeek TINYINT = NULL
	,@ExpatBasicAnnualLeaveBalance TINYINT = NULL
	,@ExpatWorkingDays TINYINT = NULL
	,@ExpatWorkingHours TINYINT = NULL
	,@ExpatOffDaysbyWeek TINYINT = NULL
	,@ExpatWorkingHoursByWeek TINYINT = NULL
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CompanyId SMALLINT
	,@GroupTeamId INT
	,@PICEmpId INT
	,@DepartmentId INT
	,@AccountableArea VARCHAR(200)
AS
/*
Created: Tom.Vo@2013-10-23
Task: Update group 
DB: HRM_SMS
Original:

Revisions:
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

	DECLARE @xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)
		,@OldHeadId INT
		,@OldManagerIds VARCHAR(MAX) = ''
		,@OldLeaderIds VARCHAR(MAX)
		,@OldSupervisorIds VARCHAR(MAX)

	SELECT @OldHeadId = EmpId
	FROM dbo.GroupManager WITH (NOLOCK)
	WHERE GroupId = @TeamId
		AND RoleId = 1

	SELECT @OldManagerIds = COALESCE(@OldManagerIds + ',', '') + CAST(EmpId AS VARCHAR(10))
	FROM dbo.GroupManager WITH (NOLOCK)
	WHERE GroupId = @TeamId
		AND RoleId = 2

	SELECT @OldLeaderIds = COALESCE(@OldLeaderIds + ',', '') + CAST(EmpId AS VARCHAR(10))
	FROM dbo.GroupManager WITH (NOLOCK)
	WHERE GroupId = @TeamId
		AND RoleId = 3

	SELECT @OldSupervisorIds = COALESCE(@OldSupervisorIds + ',', '') + CAST(EmpId AS VARCHAR(10))
	FROM dbo.GroupManager WITH (NOLOCK)
	WHERE GroupId = @TeamId
		AND RoleId = 4

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,@OldManagerIds AS '@ManagerIds'
				,@OldLeaderIds AS '@LeaderIds'
				,@OldSupervisorIds AS '@SupervisorIds'
				,MailGroup AS '@MailGroup'
				,LocalBasicAnnualLeaveBalance AS '@LocalBasicAnnualLeaveBalance'
				,LocalWorkingDays AS '@LocalWorkingDays'
				,LocalWorkingHours AS '@LocalWorkingHours'
				,LocalOffDaysbyWeek AS '@LocalOffDaysbyWeek'
				,LocalWorkingHoursByWeek AS '@LocalWorkingHoursByWeek'
				,ExpatBasicAnnualLeaveBalance AS '@ExpatBasicAnnualLeaveBalance'
				,ExpatWorkingDays AS '@ExpatWorkingDays'
				,ExpatWorkingHours AS '@ExpatWorkingHours'
				,ExpatOffDaysbyWeek AS '@ExpatOffDaysbyWeek'
				,ExpatWorkingHoursByWeek AS '@ExpatWorkingHoursByWeek'
				,CompanyId AS '@CompanyId'
				,GroupTeamId AS '@GroupTeamId'
				,PICEmpId AS '@PICEmpId'
				,DepartmentId AS '@DepartmentId'
				,AccountableArea AS '@AccountTableArea'
			FROM dbo.[Group] WITH (NOLOCK)
			WHERE GroupId = @TeamId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	DELETE
	FROM dbo.GroupManager WITH (ROWLOCK, UPDLOCK)
	WHERE GroupId = @TeamId

	IF ISNULL(@LeaderIds, '') <> ''
	BEGIN
		INSERT INTO dbo.GroupManager (GroupId, EmpId, RoleId)
		SELECT @TeamId, val, 3
		FROM dbo.fnc_strSplit(@LeaderIds, ',')
	END

	IF ISNULL(@SupervisorIds, '') <> ''
	BEGIN
		INSERT INTO dbo.GroupManager (GroupId, EmpId, RoleId)
		SELECT @TeamId, val, 4
		FROM dbo.fnc_strSplit(@SupervisorIds, ',')
	END

	UPDATE dbo.[Group] WITH (ROWLOCK, UPDLOCK)
	SET Code = @Code
		,[Name] = @Name
		,[MailGroup] = @MailGroup
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
		,LocalBasicAnnualLeaveBalance = @LocalBasicAnnualLeaveBalance
		,LocalWorkingDays = @LocalWorkingDays
		,LocalWorkingHours = @LocalWorkingHours
		,LocalOffDaysbyWeek = @LocalOffDaysbyWeek
		,LocalWorkingHoursByWeek = @LocalWorkingHoursByWeek
		,ExpatBasicAnnualLeaveBalance = @ExpatBasicAnnualLeaveBalance
		,ExpatWorkingDays = @ExpatWorkingDays
		,ExpatWorkingHours = @ExpatWorkingHours
		,ExpatOffDaysbyWeek = @ExpatOffDaysbyWeek
		,ExpatWorkingHoursByWeek = @ExpatWorkingHoursByWeek
		,CompanyId = @CompanyId
		,GroupTeamId = @GroupTeamId
		,PICEmpId = @PICEmpId
		,DepartmentId = @DepartmentId
		,AccountableArea = @AccountableArea
	WHERE GroupId = @TeamId

	SET @xml = (
			SELECT Code AS '@Code'
				,[Name] AS '@Name'
				,@ManagerIds AS '@ManagerIds'
				,@LeaderIds AS '@LeaderIds'
				,@SupervisorIds AS '@SupervisorIds'
				,MailGroup AS '@MailGroup'
				,LocalBasicAnnualLeaveBalance AS '@LocalBasicAnnualLeaveBalance'
				,LocalWorkingDays AS '@LocalWorkingDays'
				,LocalWorkingHours AS '@LocalWorkingHours'
				,LocalOffDaysbyWeek AS '@LocalOffDaysbyWeek'
				,LocalWorkingHoursByWeek AS '@LocalWorkingHoursByWeek'
				,ExpatBasicAnnualLeaveBalance AS '@ExpatBasicAnnualLeaveBalance'
				,ExpatWorkingDays AS '@ExpatWorkingDays'
				,ExpatWorkingHours AS '@ExpatWorkingHours'
				,ExpatOffDaysbyWeek AS '@ExpatOffDaysbyWeek'
				,ExpatWorkingHoursByWeek AS '@ExpatWorkingHoursByWeek'
				,CompanyId as '@CompanyId'
				,GroupTeamId as '@GroupTeamId'
				,PICEmpId as '@PICEmpId'
				,DepartmentId as '@DepartmentId'
				,AccountableArea as '@AccountableArea'
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
