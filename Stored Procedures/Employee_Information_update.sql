/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_Information_update]
(
    @EmpId INT
    ,@Code VARCHAR(20)
    ,@DomainUsername VARCHAR(50) = ''
    ,@FullName NVARCHAR(50) = ''
    ,@Nickname NVARCHAR(20) = ''
    ,@DOB DATE = NULL
    ,@Email VARCHAR(50) = NULL
    ,@JobTitleId INT = NULL
    ,@JobLevelId INT = NULL
    ,@ManagementLevelId SMALLINT = NULL
    ,@Enabled BIT
    ,@Phone VARCHAR(50) = NULL
    ,@Gender TINYINT = NULL
    ,@TeamId INT
    ,@Roles VARCHAR(20)
    ,@JoinedDate DATE = NULL
    ,@ConfirmedDate DATE = NULL
    ,@ResignedDate DATE = NULL
    ,@ResignedReason NVARCHAR(200) = NULL
    ,@LetsTalk VARCHAR(100) = NULL
    ,@Marriage TINYINT = 1
    ,@ModifiedBy INT
    ,@PermanentAddress NVARCHAR(250) = ''
    ,@CurrentAddress NVARCHAR(250) = ''
    ,@IdCardNumber VARCHAR(20) = ''
    ,@PassportNo VARCHAR(35) = ''
    ,@PassportExp DATE = NULL
    ,@ChineseName NVARCHAR(200) = NULL
    ,@CanOT BIT
    ,@SpecialOT DECIMAL(3, 1) = NULL
    ,@IsLocal BIT
    ,@WorkingDays INT
    ,@WorkingHours INT
    ,@WorkingHoursByWeek TINYINT = NULL
    ,@CompanyDate DATE = NULL
    ,@CountryCode VARCHAR(5) = NULL
    ,@IsTopManager BIT = 0
    ,@OffDaysbyWeek SMALLINT = 0
    ,@IsExpatUseHoliday BIT = 0
    ,@PlaceOfbirth NVARCHAR(250) = ''
    ,@Ethnic NVARCHAR(250) = ''
    ,@Native NVARCHAR(250) = ''
    ,@Religion NVARCHAR(250) = ''
    ,@DateOfIDCard DATE = NULL
    ,@PlaceOfIDCard NVARCHAR(250) = ''
    ,@HomePhone NVARCHAR(250) = ''
    ,@Qualification NVARCHAR(300) = ''
    ,@Major NVARCHAR(300) = ''
    ,@EmployeeCard VARCHAR(10) = ''
    ,@PickupRemark NVARCHAR(200) = NULL
    ,@PromotionDate DATE = NULL
    ,@TeamDate DATE = NULL
    ,@MilitaryFromDate DATE = NULL
    ,@MilitaryToDate DATE = NULL
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
    ,@CompanyId SMALLINT
    ,@SubCompanyId INT = NULL
    ,@SalaryStructureId INT = NULL
    ,@SpecialSubsidy VARCHAR(100) = NULL
    ,@AutoApproveRequest BIT = 0
	,@AllowanceItemSettingIds NVARCHAR(MAX) = NULL
)
AS
/*
    Created: Tom
    Task: update an employee Information 
    DB: bodb_HRM

    Revisions:
        - 20250619@Henry: fix ambiguous column error
        - 20250707@Tim: add salary structure [Redmine: #230542]
        - 20250722@Tim: add auto approve request [Remine: #233324]
		- 20250812@Mira: tranfer employee [Redmine: #235678]
		- 20251017@Henry: update payroll settings [Redmine: #241812]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @EmpId_exist INT
		,@Nickname_exist NVARCHAR(20)
		,@FullName_exist NVARCHAR(50)
		,@Code_exist NVARCHAR(50)
		,@Roles_old VARCHAR(100)
		,@Enabled_old BIT
		,@IsDeleted_old BIT
		,@IsDefaultSchedule_old BIT
		,@AnnualLeaveBalance_old NUMERIC(18, 1) = 0
		,@KeepInViewBalance_old NUMERIC(18, 1) = 0
		,@xml XML
		,@logData NVARCHAR(MAX)
		,@logOldData NVARCHAR(MAX)
		,@UserId INT
		,@OldAllowanceItemSettingIds NVARCHAR(MAX) = ''

	SELECT @UserId = UserId
	FROM dbo.CompanyEmployee ce
	WHERE ce.EmpId = @EmpId

	SELECT TOP 1 @EmpId_exist = ce.EmpId
		,@FullName_exist = e.FullName
	FROM dbo.Employee e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee ce WITH(NOLOCK) ON ce.UserId = e.UserId
	WHERE ce.EmpId <> @EmpId
		AND ce.Code = @code
		AND ce.CompanyId = @CompanyId


	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Code ' + @Code + ' has been assigned to ' + @FullName_exist

		RETURN
	END

	SELECT TOP 1 @EmpId_exist = ce.EmpId
		,@Nickname_exist = ce.Nickname
		,@FullName_exist = e.FullName
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee ce WITH(NOLOCK) ON ce.UserId = e.UserId
	WHERE ce.EmpId <> @EmpId
		AND ce.Nickname = @nickname
		AND ce.CompanyId = @CompanyId
		AND (
			ce.isDeleted = 0
			OR ce.[Enabled] = 1
			)

	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Nickname  ' + @Nickname_exist + '  has been assigned to ' + @FullName_exist

		RETURN
	END

	SELECT @Enabled_old = [Enabled]
		,@IsDeleted_old = isDeleted
	FROM dbo.CompanyEmployee WITH (NOLOCK)
	WHERE EmpId = @EmpId
	
	SELECT @IsDefaultSchedule_old = IsDefaultSchedule
		,@AnnualLeaveBalance_old = AnnualLeaveBalance
		,@KeepInViewBalance_old = KeepInViewBalance
	FROM dbo.EmployeeSummary WITH (NOLOCK)
	WHERE EmpId = @EmpId

	SELECT @Roles_old = COALESCE(@Roles_old + ',', '') + CONVERT(NVARCHAR(2), RoleId)
	FROM dbo.EmployeeRole WITH (NOLOCK)
	WHERE EmployeeId = @EmpId
	Order by RoleID

	SELECT @OldAllowanceItemSettingIds = COALESCE(@OldAllowanceItemSettingIds + ',', '') + CAST(AllowanceItemSettingId AS NVARCHAR(10))
	FROM dbo.EmployeePayrollAllowance WITH (NOLOCK)
	WHERE EmpId = @EmpId
	ORDER BY AllowanceItemSettingId ASC 

	SET @xml = (
			SELECT ce.Code AS '@Code'
				,ce.DomainUsername AS '@DomainUsername'
				,e.FullName AS '@FullName'
				,ce.Nickname AS '@Nickname'
				,e.DOB AS '@DOB'
				,ce.Email AS '@Email'
				,ce.JobTitleId AS '@JobTitleId'
				,ce.JobLevelId AS '@JobLevelId'
				,ce.ManagementLevelId AS'@ManagementLevelId'
				,ce.[Enabled] AS '@Enabled'
				,ce.isDeleted AS '@IsDeleted'
				,e.Phone AS '@Phone'
				,e.Gender AS '@Gender'
				,ce.GroupId AS '@TeamId'
				,e.JoinedDate AS '@JoinedDate'
				,e.ConfirmedDate AS '@ConfirmedDate'
				,e.ResignedDate AS '@ResignedDate'
				,e.ResignedReason AS '@ResignedReason'
				,e.LetsTalk AS '@LetsTalk'
				,e.Marriage AS '@Marriage'
				,e.PermanentAddress AS '@PermanentAddress'
				,e.CurrentAddress AS '@CurrentAddress'
				,e.IdCardNumber AS '@IdCardNumber'
				,e.PassportNo AS '@PassportNo'
				,e.PassportExp AS '@PassportExp'
				,e.ChineseName AS '@ChineseName'
				,e.PlaceOfbirth AS '@PlaceOfbirth'
				,e.Ethnic AS '@Ethnic'
				,e.[Native] AS '@Native'
				,e.Religion AS '@Religion'
				,e.DateOfIDCard AS '@DateOfIDCard'
				,e.PlaceOfIDCard AS '@PlaceOfIDCard'
				,e.HomePhone AS '@HomePhone'
				,e.Qualification AS '@Qualification'
				,e.Major AS '@Major'
				,ce.EmployeeCard AS '@EmployeeCard'
				,ce.PickupRemark AS '@PickupRemark'
				,ce.PromotionDate AS '@PromotionDate'
				,ce.TeamDate AS '@TeamDate'
				,@Roles_old AS '@RoleIds'
				,empsum.CanOT AS '@CanOT'
				,empsum.SpecialOT AS '@SpecialOT'
				,empsum.IsLocal AS '@IsLocal'
				,empsum.WorkingDays AS '@WorkingDays'
				,empsum.WorkingHours AS '@WorkingHours'
				,empsum.WorkingHoursByWeek AS '@WorkingHoursByWeek'
				,ce.IsSpecialUser AS '@IsTopManager'
				,ce.CompanyDate AS '@CompanyDate'
				,empsum.CountryCode AS '@CountryCode'
				,empsum.IsExpatUseHoliday AS '@IsExpatUseHoliday'
				,empsum.OffDaysbyWeek AS '@OffDaysbyWeek'
				,e.MilitaryFromDate AS '@MilitaryFromDate'
				,e.MilitaryToDate AS '@MilitaryToDate'
				,ce.SubCompanyId AS '@SubCompanyId'
                ,ce.AutoApproveRequest AS '@AutoApproveRequest'
				,ep.SalaryStructureId AS '@SalaryStructureId'
				,ep.SpecialSubsidy AS '@SpecialSubsidy'
				,@OldAllowanceItemSettingIds AS '@AllowanceItemSettingIds'
			FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
				INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId
				LEFT JOIN dbo.EmployeePayroll AS ep WITH (NOLOCK) ON ce.EmpId = ep.EmpId
                AND ce.CompanyId = @CompanyId
			WHERE ce.EmpId = @EmpId
			FOR XML PATH('Row')
				,TYPE
			)
	
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	IF @Enabled_old = 0 AND @Enabled = 1 AND @IsDeleted_old = 1
	BEGIN
		UPDATE dbo.CompanyEmployee WITH (ROWLOCK, UPDLOCK)
		SET isDeleted = 0
		WHERE EmpId = @EmpId
	END

	UPDATE dbo.Employee WITH (ROWLOCK)
	SET FullName = @FullName		
		,DOB = @DOB		
		,Phone = @Phone
		,Gender = @Gender
		,JoinedDate = @JoinedDate
		,ConfirmedDate = @ConfirmedDate
		,ResignedDate = @ResignedDate
		,ResignedReason = @ResignedReason
		,LetsTalk = @LetsTalk
		,Marriage = @Marriage
		,PermanentAddress = @PermanentAddress
		,CurrentAddress = @CurrentAddress
		,IdCardNumber = @IdCardNumber
		,PassportNo = @PassportNo
		,PassportExp = @PassportExp
		,ChineseName = @ChineseName
		,PlaceOfbirth = @PlaceOfbirth
		,Ethnic = @Ethnic
		,[Native] = @Native
		,Religion = @Religion
		,DateOfIDCard = @DateOfIDCard
		,PlaceOfIDCard = @PlaceOfIDCard
		,HomePhone = @HomePhone
		,Qualification = @Qualification
		,Major = @Major		
		,MilitaryFromDate = @MilitaryFromDate
		,MilitaryToDate = @MilitaryToDate
	WHERE UserId = @UserId

	UPDATE CompanyEmployee  WITH (ROWLOCK)
	SET SubCompanyId = @SubCompanyId
        ,AutoApproveRequest = @AutoApproveRequest
		,Code = @Code
		,DomainUsername = @DomainUsername
		,Nickname = @Nickname
		,EmployeeCard = @EmployeeCard
		,PickupRemark = @PickupRemark
		,PromotionDate = @PromotionDate
		,TeamDate = @TeamDate
		,Email = REPLACE(@Email, ' ', '')
		,JobTitleId = @JobTitleId
		,JobLevelId = @JobLevelId
		,ManagementLevelId = @ManagementLevelId
		,[Enabled] = @Enabled
		,GroupId = @TeamId
		,IsSpecialUser = @IsTopManager
		,CompanyDate = @CompanyDate
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
	WHERE EmpId = @EmpId
        AND CompanyId = @CompanyId

	EXEC dbo.EmployeePayroll_Upsert 
		@EmpId = @EmpId,
		@SalaryStructureId = @SalaryStructureId,
		@SpecialSubsidy = @SpecialSubsidy,
		@NoOfDependent = 0,
		@AllowanceItemSettingIds = @AllowanceItemSettingIds,
		@ModifiedBy = @ModifiedBy,
		@ErrCode = @ErrCode OUTPUT,
		@ErrMsg = @ErrMsg OUTPUT

	EXEC dbo.EmployeeRole_Update @EmployeeId = @EmpId
		,@RoleIds = @Roles
		,@ModifiedBy = @ModifiedBy

	EXEC dbo.Employee_Summary_Update @EmpId = @EmpId
		,@AnnualLeaveBalance = @AnnualLeaveBalance_old
		,@KeepInViewBalance = @KeepInViewBalance_old
		,@CanOT = @CanOT
		,@SpecialOT = @SpecialOT
		,@IsLocal = @IsLocal
		,@WorkingDays = @WorkingDays
		,@WorkingHours = @WorkingHours
		,@WorkingHoursByWeek = @WorkingHoursByWeek
		,@CompanyDate = @CompanyDate
		,@CountryCode = @CountryCode
		,@IsDefaultSchedule = @IsDefaultSchedule_old
		,@IsTopManager = @IsTopManager
		,@OffDaysbyWeek = @OffDaysbyWeek
		,@IsExpatUseHoliday = @IsExpatUseHoliday
		,@MilitaryFromDate = @MilitaryFromDate
		,@MilitaryToDate = @MilitaryToDate
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	SET @xml = (
			SELECT ce.Code AS '@Code'
				,ce.DomainUsername AS '@DomainUsername'
				,e.FullName AS '@FullName'
				,ce.Nickname AS '@Nickname'
				,e.DOB AS '@DOB'
				,ce.Email AS '@Email'
				,ce.JobTitleId AS '@JobTitleId'
				,ce.JobLevelId AS '@JobLevelId'
				,ce.ManagementLevelId AS '@ManagementLevelId'
				,ce.[Enabled] AS '@Enabled'
				,ce.isDeleted AS '@IsDeleted'
				,e.Phone AS '@Phone'
				,e.Gender AS '@Gender'
				,ce.GroupId AS '@TeamId'
				,e.JoinedDate AS '@JoinedDate'
				,e.ConfirmedDate AS '@ConfirmedDate'
				,e.ResignedDate AS '@ResignedDate'
				,e.ResignedReason AS '@ResignedReason'
				,e.LetsTalk AS '@LetsTalk'
				,e.Marriage AS '@Marriage'
				,e.PermanentAddress AS '@PermanentAddress'
				,e.CurrentAddress AS '@CurrentAddress'
				,e.IdCardNumber AS '@IdCardNumber'
				,e.PassportNo AS '@PassportNo'
				,e.PassportExp AS '@PassportExp'
				,e.ChineseName AS '@ChineseName'
				,e.PlaceOfbirth AS '@PlaceOfbirth'
				,e.Ethnic AS '@Ethnic'
				,e.[Native] AS '@Native'
				,e.Religion AS '@Religion'
				,e.DateOfIDCard AS '@DateOfIDCard'
				,e.PlaceOfIDCard AS '@PlaceOfIDCard'
				,e.HomePhone AS '@HomePhone'
				,e.Qualification AS '@Qualification'
				,e.Major AS '@Major'
				,ce.EmployeeCard AS '@EmployeeCard'
				,ce.PickupRemark AS '@PickupRemark'
				,ce.PromotionDate AS '@PromotionDate'
				,ce.TeamDate AS '@TeamDate'
				,@Roles AS '@RoleIds'
				,empsum.CanOT AS '@CanOT'
				,empsum.SpecialOT AS '@SpecialOT'
				,empsum.IsLocal AS '@IsLocal'
				,empsum.WorkingDays AS '@WorkingDays'
				,empsum.WorkingHours AS '@WorkingHours'
				,empsum.WorkingHoursByWeek AS '@WorkingHoursByWeek'
				,ce.IsSpecialUser AS '@IsTopManager'
				,ce.CompanyDate AS '@CompanyDate'
				,empsum.CountryCode AS '@CountryCode'
				,empsum.IsExpatUseHoliday AS '@IsExpatUseHoliday'
				,empsum.OffDaysbyWeek AS '@OffDaysbyWeek'
				,e.MilitaryFromDate AS '@MilitaryFromDate'
				,e.MilitaryToDate AS '@MilitaryToDate'
				,ce.SubCompanyId AS '@SubCompanyId'
				,ce.AutoApproveRequest AS '@AutoApproveRequest'
				,ep.SalaryStructureId AS '@SalaryStructureId'
				,ep.SpecialSubsidy AS '@SpecialSubsidy'
				,@AllowanceItemSettingIds AS '@AllowanceItemSettingIds'
			FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON ce.EmpId = empsum.EmpId
				INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON ce.UserId = e.UserId
				LEFT JOIN dbo.EmployeePayroll AS ep WITH (NOLOCK) ON ce.EmpId = ep.EmpId
                AND ce.CompanyId = @CompanyId
			WHERE ce.EmpId = @EmpId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 1
		,@ObjectId = @EmpId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END