/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_Information_update] @EmpId INT
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
	,@Skype VARCHAR(100) = NULL
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
AS
/*
Created: TOM
Task: UPDATE an employee Information 
DB: HRM

Revisions:
	-Henry- 19062025: fix ambiguous column error
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

	SELECT TOP 1 @EmpId_exist = e.EmpId
		,@FullName_exist = e.FullName
	FROM dbo.Employee e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee c WITH(NOLOCK) ON c.EmpId = e.EmpId
	WHERE e.EmpId <> @EmpId
		AND Code = @code
		AND c.CompanyId = @CompanyId


	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Code ' + @Code + ' has been assigned to ' + @FullName_exist

		RETURN
	END

	SELECT TOP 1 @EmpId_exist = e.EmpId
		,@Nickname_exist = Nickname
		,@FullName_exist = FullName
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee c WITH(NOLOCK) ON c.EmpId = e.EmpId
	WHERE e.EmpId <> @EmpId
		AND Nickname = @nickname
		AND c.CompanyId = @CompanyId
		AND (
			e.isDeleted = 0
			OR e.[Enabled] = 1
			)

	IF ISNULL(@EmpId_exist, 0) <> 0
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = N'Nickname  ' + @Nickname_exist + '  has been assigned to ' + @FullName_exist

		RETURN
	END

	SELECT @Enabled_old = [Enabled]
		,@IsDeleted_old = isDeleted
	FROM dbo.Employee WITH (NOLOCK)
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

	SET @xml = (
			SELECT Code AS '@Code'
				,DomainUsername AS '@DomainUsername'
				,FullName AS '@FullName'
				,Nickname AS '@Nickname'
				,DOB AS '@DOB'
				,Email AS '@Email'
				,JobTitleId AS '@JobTitleId'
				,JobLevelId AS '@JobLevelId'
				,ManagementLevelId AS'@ManagementLevelId'
				,[Enabled] AS '@Enabled'
				,emp.isDeleted AS '@IsDeleted'
				,Phone AS '@Phone'
				,Gender AS '@Gender'
				,GroupId AS '@TeamId'
				,JoinedDate AS '@JoinedDate'
				,ConfirmedDate AS '@ConfirmedDate'
				,ResignedDate AS '@ResignedDate'
				,ResignedReason AS '@ResignedReason'
				,Skype AS '@Skype'
				,LetsTalk AS '@LetsTalk'
				,Marriage AS '@Marriage'
				,PermanentAddress AS '@PermanentAddress'
				,CurrentAddress AS '@CurrentAddress'
				,IdCardNumber AS '@IdCardNumber'
				,PassportNo AS '@PassportNo'
				,PassportExp AS '@PassportExp'
				,ChineseName AS '@ChineseName'
				,PlaceOfbirth AS '@PlaceOfbirth'
				,Ethnic AS '@Ethnic'
				,[Native] AS '@Native'
				,Religion AS '@Religion'
				,DateOfIDCard AS '@DateOfIDCard'
				,PlaceOfIDCard AS '@PlaceOfIDCard'
				,HomePhone AS '@HomePhone'
				,Qualification AS '@Qualification'
				,Major AS '@Major'
				,EmployeeCard AS '@EmployeeCard'
				,PickupRemark AS '@PickupRemark'
				,PromotionDate AS '@PromotionDate'
				,TeamDate AS '@TeamDate'
				,@Roles_old AS '@RoleIds'
				,CanOT AS '@CanOT'
				,SpecialOT AS '@SpecialOT'
				,IsLocal AS '@IsLocal'
				,WorkingDays AS '@WorkingDays'
				,WorkingHours AS '@WorkingHours'
				,WorkingHoursByWeek AS '@WorkingHoursByWeek'
				,IsTopManager AS '@IsTopManager'
				,CompanyDate AS '@CompanyDate'
				,CountryCode AS '@CountryCode'
				,IsExpatUseHoliday AS '@IsExpatUseHoliday'
				,OffDaysbyWeek AS '@OffDaysbyWeek'
				,MilitaryFromDate AS '@MilitaryFromDate'
				,MilitaryToDate AS '@MilitaryToDate'
				,SubCompanyId AS '@SubCompanyId'
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
				INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
			WHERE emp.EmpId = @EmpId
			FOR XML PATH('Row')
				,TYPE
			)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	IF @Enabled_old = 0 AND @Enabled = 1 AND @IsDeleted_old = 1
	BEGIN
		UPDATE dbo.Employee WITH (ROWLOCK, UPDLOCK)
		SET isDeleted = 0
		WHERE EmpId = @EmpId
	END

	UPDATE dbo.Employee WITH (ROWLOCK, UPDLOCK)
	SET Code = @Code
		,DomainUsername = @DomainUsername
		,FullName = @FullName
		,Nickname = @Nickname
		,DOB = @DOB
		,Email = REPLACE(@Email, ' ', '')
		,JobTitleId = @JobTitleId
		,JobLevelId = @JobLevelId
		,ManagementLevelId = @ManagementLevelId
		,[Enabled] = @Enabled
		,Phone = @Phone
		,Gender = @Gender
		,GroupId = @TeamId
		,JoinedDate = @JoinedDate
		,ConfirmedDate = @ConfirmedDate
		,ResignedDate = @ResignedDate
		,ResignedReason = @ResignedReason
		,Skype = @Skype
		,LetsTalk = @LetsTalk
		,Marriage = @Marriage
		,ModifiedDate = GETDATE()
		,ModifiedBy = @ModifiedBy
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
		,EmployeeCard = @EmployeeCard
		,PickupRemark = @PickupRemark
		,PromotionDate = @PromotionDate
		,TeamDate = @TeamDate
	WHERE EmpId = @EmpId

	UPDATE CompanyEmployee  WITH (ROWLOCK, UPDLOCK)
	SET SubCompanyId = @SubCompanyId
	WHERE EmpId = @EmpId

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
			SELECT Code AS '@Code'
				,DomainUsername AS '@DomainUsername'
				,FullName AS '@FullName'
				,Nickname AS '@Nickname'
				,DOB AS '@DOB'
				,Email AS '@Email'
				,JobTitleId AS '@JobTitleId'
				,JobLevelId AS '@JobLevelId'
				,ManagementLevelId AS '@ManagementLevelId'
				,[Enabled] AS '@Enabled'
				,emp.isDeleted AS '@IsDeleted'
				,Phone AS '@Phone'
				,Gender AS '@Gender'
				,GroupId AS '@TeamId'
				,JoinedDate AS '@JoinedDate'
				,ConfirmedDate AS '@ConfirmedDate'
				,ResignedDate AS '@ResignedDate'
				,ResignedReason AS '@ResignedReason'
				,Skype AS '@Skype'
				,LetsTalk AS '@LetsTalk'
				,Marriage AS '@Marriage'
				,PermanentAddress AS '@PermanentAddress'
				,CurrentAddress AS '@CurrentAddress'
				,IdCardNumber AS '@IdCardNumber'
				,PassportNo AS '@PassportNo'
				,PassportExp AS '@PassportExp'
				,ChineseName AS '@ChineseName'
				,PlaceOfbirth AS '@PlaceOfbirth'
				,Ethnic AS '@Ethnic'
				,[Native] AS '@Native'
				,Religion AS '@Religion'
				,DateOfIDCard AS '@DateOfIDCard'
				,PlaceOfIDCard AS '@PlaceOfIDCard'
				,HomePhone AS '@HomePhone'
				,Qualification AS '@Qualification'
				,Major AS '@Major'
				,EmployeeCard AS '@EmployeeCard'
				,PickupRemark AS '@PickupRemark'
				,PromotionDate AS '@PromotionDate'
				,TeamDate AS '@TeamDate'
				,@Roles AS '@RoleIds'
				,CanOT AS '@CanOT'
				,SpecialOT AS '@SpecialOT'
				,IsLocal AS '@IsLocal'
				,WorkingDays AS '@WorkingDays'
				,WorkingHours AS '@WorkingHours'
				,WorkingHoursByWeek AS '@WorkingHoursByWeek'
				,IsTopManager AS '@IsTopManager'
				,CompanyDate AS '@CompanyDate'
				,CountryCode AS '@CountryCode'
				,IsExpatUseHoliday AS '@IsExpatUseHoliday'
				,OffDaysbyWeek AS '@OffDaysbyWeek'
				,MilitaryFromDate AS '@MilitaryFromDate'
				,MilitaryToDate AS '@MilitaryToDate'
				,SubCompanyId AS '@SubCompanyId'
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
				INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
			WHERE emp.EmpId = @EmpId
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
