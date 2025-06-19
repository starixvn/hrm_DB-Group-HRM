/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Group_Update]
(
    @TeamId INT
    ,@Code VARCHAR(20)
    ,@Name NVARCHAR(150)
    ,@ModifiedBy INT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
    ,@PICEmpId INT = NULL
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
	,@IsOutsource BIT = 0
)
AS
/*
    Created: Tom.Vo@2013-10-23
    Task: Update group 
    DB: bodb_HRM

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
				,IsOutsource AS '@IsOutsource'
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
		,IsOutsource = @IsOutsource
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
				,IsOutsource AS '@IsOutsource'
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