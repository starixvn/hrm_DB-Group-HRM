USE [bodb_HRM]
GO

ALTER PROCEDURE [dbo].[Employee_GetEmployeeByID] @EmpId INT
AS
/*
    Created: Tom.Vo@2013-10-21
    Task: get employee by id
    DB: bodb_HRM

    Revisions:
        03062023@Otis: get field ResignedReason
        20250707@Tim: add salary structure [Redmine: #230542]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @KIVLeaveBalance NUMERIC(18, 2)
		,@AnnualLeaveBalance NUMERIC(18, 2)
		,@Today DATE = GETDATE()

	SELECT @KIVLeaveBalance = dbo.fnc_GetKIVByDayBalance(@EmpID, @Today, NULL)
		,@AnnualLeaveBalance = dbo.fnc_GetAnnualLeaveBalance(@EmpId, @Today, NULL)

	SELECT e.EmpId
		,e.UserId
		,e.Code
		,e.DomainUsername
		,e.FullName
		,e.NickName
		,e.EmployeeCard
		,e.DOB AS DateOfBirth
		,e.Email
		,e.[Enabled]
		,e.Phone
		,e.Gender
		,e.TeamDate
		,e.PromotionDate
		,e.JoinedDate
		,e.ConfirmedDate
		,e.ResignedDate
		,e.ResignedReason
		,empsum.CompanyDate
		,empsum.WorkingDays
		,empsum.WorkingHours
		,empsum.MilitaryFromDate
		,empsum.MilitaryToDate
		,empsum.WorkingHoursByWeek
		,e.Skype
		,e.LetsTalk
		,e.Marriage
		,e.LastLogin
		,@AnnualLeaveBalance AS AnnualLeaveBalance
		,@KIVLeaveBalance AS KeepInViewBalance
		,empsum.CountryCode
		,ct.CountryName
		,empsum.CanOT
		,empsum.SpecialOT
		,empsum.IsLocal
		,empsum.IsExpatUseHoliday
		,e.CreatedDate
		,e.CreatedBy
		,e.ModifiedDate
		,e.ModifiedBy
		,e.isDeleted
		,e.PermanentAddress AS [Address]
		,e.CurrentAddress
		,e.IdCardNumber AS CardNo
		,e.PassportNo
		,e.PassportExp
		,e.[Password]
		,e.ChineseName
		,empsum.IsDefaultSchedule
		,empsum.IsTopManager
		,empsum.OffDaysbyWeek
		,empsum.Unit
		,e.PlaceOfbirth
		,e.Ethnic
		,e.[Native]
		,e.Religion
		,e.DateOfIDCard
		,e.PlaceOfIDCard
		,e.HomePhone
		,e.Qualification
		,e.Major
		,e_cs.[BankAccount]
		,e_cs.[TaxCode]
		,e_cs.[SocialInsuranceNo]
		,e_cs.[RegisteredHospital]
		,e_cs.[Contract1]
		,e_cs.[FromDate1]
		,e_cs.[ToDate1]
		,e_cs.[Contract2]
		,e_cs.[FromDate2]
		,e_cs.[ToDate2]
		,e_cs.[Contract3]
		,e_cs.[FromDate3]
		,e_cs.[ToDate3]
		,e_cs.[Contract4]
		,e_cs.[FromDate4]
		,e_cs.[ToDate4]
		,e_cs.[Contract5]
		,e_cs.[FromDate5]
		,e_cs.[ToDate5]
		,e_cs.History
		,e.PasswordReset
		,e.PickupRemark
		,e.JobTitleId
		,e.ExpertGradeId
		,e.JobLevelId
		,lk.[Name] AS JobTitle
		,ce.SubCompanyId
		,e.ManagementLevelId
        ,ce.SalaryStructureId
        ,ce.Salary
		,ISNULL(e.GroupId, - 1) AS [TeamId]
		,g.Code
		,g.[Name]
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON empsum.EmpId = e.EmpId
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = e.EmpId
		INNER JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		LEFT JOIN dbo.EmployeeContract AS e_cs WITH (NOLOCK) ON e_cs.EmpId = e.EmpId
		LEFT JOIN dbo.Country AS ct WITH (NOLOCK) ON empsum.CountryCode = ct.CountryCode
		LEFT JOIN dbo.LookupData AS lk WITH (NOLOCK) ON e.JobTitleId = lk.Id
		AND lk.LookupId = 1
	WHERE e.EmpId = @EmpId
END
GO

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
    ,@SalaryStructureId INT = NULL
    ,@Salary VARCHAR(100) = NULL
)
AS
/*
    Created: TOM
    Task: update an employee Information 
    DB: bodb_HRM

    Revisions:
        - 20250619@Henry: fix ambiguous column error
        - 20250707@Tim: add salary structure [Redmine: #230542]
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
			SELECT emp.Code AS '@Code'
				,emp.DomainUsername AS '@DomainUsername'
				,emp.FullName AS '@FullName'
				,emp.Nickname AS '@Nickname'
				,emp.DOB AS '@DOB'
				,emp.Email AS '@Email'
				,emp.JobTitleId AS '@JobTitleId'
				,emp.JobLevelId AS '@JobLevelId'
				,emp.ManagementLevelId AS'@ManagementLevelId'
				,emp.[Enabled] AS '@Enabled'
				,emp.isDeleted AS '@IsDeleted'
				,emp.Phone AS '@Phone'
				,emp.Gender AS '@Gender'
				,emp.GroupId AS '@TeamId'
				,emp.JoinedDate AS '@JoinedDate'
				,emp.ConfirmedDate AS '@ConfirmedDate'
				,emp.ResignedDate AS '@ResignedDate'
				,emp.ResignedReason AS '@ResignedReason'
				,emp.Skype AS '@Skype'
				,emp.LetsTalk AS '@LetsTalk'
				,emp.Marriage AS '@Marriage'
				,emp.PermanentAddress AS '@PermanentAddress'
				,emp.CurrentAddress AS '@CurrentAddress'
				,emp.IdCardNumber AS '@IdCardNumber'
				,emp.PassportNo AS '@PassportNo'
				,emp.PassportExp AS '@PassportExp'
				,emp.ChineseName AS '@ChineseName'
				,emp.PlaceOfbirth AS '@PlaceOfbirth'
				,emp.Ethnic AS '@Ethnic'
				,emp.[Native] AS '@Native'
				,emp.Religion AS '@Religion'
				,emp.DateOfIDCard AS '@DateOfIDCard'
				,emp.PlaceOfIDCard AS '@PlaceOfIDCard'
				,emp.HomePhone AS '@HomePhone'
				,emp.Qualification AS '@Qualification'
				,emp.Major AS '@Major'
				,emp.EmployeeCard AS '@EmployeeCard'
				,emp.PickupRemark AS '@PickupRemark'
				,emp.PromotionDate AS '@PromotionDate'
				,emp.TeamDate AS '@TeamDate'
				,@Roles_old AS '@RoleIds'
				,empsum.CanOT AS '@CanOT'
				,empsum.SpecialOT AS '@SpecialOT'
				,empsum.IsLocal AS '@IsLocal'
				,empsum.WorkingDays AS '@WorkingDays'
				,empsum.WorkingHours AS '@WorkingHours'
				,empsum.WorkingHoursByWeek AS '@WorkingHoursByWeek'
				,empsum.IsTopManager AS '@IsTopManager'
				,empsum.CompanyDate AS '@CompanyDate'
				,empsum.CountryCode AS '@CountryCode'
				,empsum.IsExpatUseHoliday AS '@IsExpatUseHoliday'
				,empsum.OffDaysbyWeek AS '@OffDaysbyWeek'
				,empsum.MilitaryFromDate AS '@MilitaryFromDate'
				,empsum.MilitaryToDate AS '@MilitaryToDate'
				,ce.SubCompanyId AS '@SubCompanyId'
                ,ce.SalaryStructureId AS '@SalaryStructureId'
                ,ce.Salary AS '@Salary'
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

	UPDATE dbo.Employee WITH (ROWLOCK)
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

	UPDATE CompanyEmployee  WITH (ROWLOCK)
	SET SubCompanyId = @SubCompanyId
        ,SalaryStructureId = @SalaryStructureId
        ,Salary = @Salary
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
			SELECT emp.Code AS '@Code'
				,emp.DomainUsername AS '@DomainUsername'
				,emp.FullName AS '@FullName'
				,emp.Nickname AS '@Nickname'
				,emp.DOB AS '@DOB'
				,emp.Email AS '@Email'
				,emp.JobTitleId AS '@JobTitleId'
				,emp.JobLevelId AS '@JobLevelId'
				,emp.ManagementLevelId AS '@ManagementLevelId'
				,emp.[Enabled] AS '@Enabled'
				,emp.isDeleted AS '@IsDeleted'
				,emp.Phone AS '@Phone'
				,emp.Gender AS '@Gender'
				,emp.GroupId AS '@TeamId'
				,emp.JoinedDate AS '@JoinedDate'
				,emp.ConfirmedDate AS '@ConfirmedDate'
				,emp.ResignedDate AS '@ResignedDate'
				,emp.ResignedReason AS '@ResignedReason'
				,emp.Skype AS '@Skype'
				,emp.LetsTalk AS '@LetsTalk'
				,emp.Marriage AS '@Marriage'
				,emp.PermanentAddress AS '@PermanentAddress'
				,emp.CurrentAddress AS '@CurrentAddress'
				,emp.IdCardNumber AS '@IdCardNumber'
				,emp.PassportNo AS '@PassportNo'
				,emp.PassportExp AS '@PassportExp'
				,emp.ChineseName AS '@ChineseName'
				,emp.PlaceOfbirth AS '@PlaceOfbirth'
				,emp.Ethnic AS '@Ethnic'
				,emp.[Native] AS '@Native'
				,emp.Religion AS '@Religion'
				,emp.DateOfIDCard AS '@DateOfIDCard'
				,emp.PlaceOfIDCard AS '@PlaceOfIDCard'
				,emp.HomePhone AS '@HomePhone'
				,emp.Qualification AS '@Qualification'
				,emp.Major AS '@Major'
				,emp.EmployeeCard AS '@EmployeeCard'
				,emp.PickupRemark AS '@PickupRemark'
				,emp.PromotionDate AS '@PromotionDate'
				,emp.TeamDate AS '@TeamDate'
				,@Roles AS '@RoleIds'
				,empsum.CanOT AS '@CanOT'
				,empsum.SpecialOT AS '@SpecialOT'
				,empsum.IsLocal AS '@IsLocal'
				,empsum.WorkingDays AS '@WorkingDays'
				,empsum.WorkingHours AS '@WorkingHours'
				,empsum.WorkingHoursByWeek AS '@WorkingHoursByWeek'
				,empsum.IsTopManager AS '@IsTopManager'
				,empsum.CompanyDate AS '@CompanyDate'
				,empsum.CountryCode AS '@CountryCode'
				,empsum.IsExpatUseHoliday AS '@IsExpatUseHoliday'
				,empsum.OffDaysbyWeek AS '@OffDaysbyWeek'
				,empsum.MilitaryFromDate AS '@MilitaryFromDate'
				,empsum.MilitaryToDate AS '@MilitaryToDate'
				,ce.SubCompanyId AS '@SubCompanyId'
                ,ce.SalaryStructureId AS '@SalaryStructureId'
                ,ce.Salary AS '@Salary'
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
GO

CREATE PROCEDURE [dbo].[SalaryStructure_Update]
(
    @SalaryStructureId INT
    ,@CompanyId SMALLINT
	,@Name NVARCHAR(255)
	,@JobLevelId INT
    ,@LocalSalary VARCHAR(100)
    ,@ExpatSalary VARCHAR(100)
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 202507040@Tim
    Task: create salary structure
    DB: bodb_HRM

    Revisions:
        20250704@Tim: init [Redmine: #230542]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @xml XML
		,@logData NVARCHAR(MAX)
        ,@logOldData NVARCHAR(MAX)

	IF EXISTS (
		SELECT 1
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE CompanyId = @CompanyId
            AND [Name] = @Name
            AND JobLevelId = @JobLevelId
            AND SalaryStructureId != @SalaryStructureId
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The salary structure already exists.'

		RETURN
	END

    SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
		    ,JobLevelId AS '@JobLevelId'
		    ,LocalSalary AS '@LocalSalary'
		    ,ExpatSalary AS '@ExpatSalary'
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE SalaryStructureId = @SalaryStructureId
		FOR XML PATH('Row')
			,TYPE
		)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	
	UPDATE dbo.SalaryStructure WITH (ROWLOCK)
    SET CompanyId = @CompanyId
		,[Name] = @Name
		,JobLevelId = @JobLevelId
		,LocalSalary = @LocalSalary
		,ExpatSalary = @ExpatSalary
		,ModifiedBy = @ModifiedBy
		,ModifiedDate = GETDATE()
    WHERE SalaryStructureId = @SalaryStructureId

    SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
		    ,JobLevelId AS '@JobLevelId'
		    ,LocalSalary AS '@LocalSalary'
		    ,ExpatSalary AS '@ExpatSalary'
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE SalaryStructureId = @SalaryStructureId
		FOR XML PATH('Row')
			,TYPE
		)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 4
		,@ObjectId = @SalaryStructureId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO

CREATE PROCEDURE [dbo].[SalaryStructure_GetById]
(
    @SalaryStructureId INT
)
AS
/*
    Created: 202507040@Tim
    Task: get salary structure by id
    DB: bodb_HRM

    Revisions:
        20250704@Tim: init [Redmine: #230542]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ss.SalaryStructureId,
        ss.[Name],
        ss.JobLevelId,
        jl.[Name] AS JobLevelName,
        ss.LocalSalary,
        ss.ExpatSalary
    FROM dbo.SalaryStructure AS ss WITH (NOLOCK)
        INNER JOIN dbo.JobLevel AS jl WITH (NOLOCK) ON ss.JobLevelId = jl.JobLevelId
    WHERE ss.SalaryStructureId = @SalaryStructureId
END
GO

CREATE PROCEDURE [dbo].[SalaryStructure_Delete]
(
    @SalaryStructureId INT
	,@DeletedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 202507040@Tim
    Task: delete salary structure
    DB: bodb_HRM

    Revisions:
        20250704@Tim: init [Redmine: #230542]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @xml XML
        ,@logOldData NVARCHAR(MAX)

	IF EXISTS (
		SELECT 1
		FROM dbo.CompanyEmployee WITH (NOLOCK)
		WHERE SalaryStructureId = @SalaryStructureId
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The salary structure cannot be deleted because it is already in use.'

		RETURN
	END

    SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
		    ,JobLevelId AS '@JobLevelId'
		    ,LocalSalary AS '@LocalSalary'
		    ,ExpatSalary AS '@ExpatSalary'
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE SalaryStructureId = @SalaryStructureId
		FOR XML PATH('Row')
			,TYPE
		)
	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	
	DELETE dbo.SalaryStructure WITH (ROWLOCK)
    WHERE SalaryStructureId = @SalaryStructureId

	EXEC dbo.ActivityLog_Insert @UserId = @DeletedBy
		,@ObjectTypeId = 4
		,@ObjectId = @SalaryStructureId
		,@OldData = @logOldData
		,@Data = NULL
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO

CREATE PROCEDURE [dbo].[SalaryStructure_Get]
(
    @CompanyId SMALLINT
)
AS
/*
    Created: 202507040@Tim
    Task: get salary structure
    DB: bodb_HRM

    Revisions:
        20250704@Tim: init [Redmine: #230542]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ss.SalaryStructureId, ss.[Name], ss.JobLevelId, jl.[Name] AS JobLevelName, ss.LocalSalary, ss.ExpatSalary
    FROM dbo.SalaryStructure AS ss WITH (NOLOCK)
        INNER JOIN dbo.JobLevel AS jl WITH (NOLOCK) ON ss.JobLevelId = jl.JobLevelId
    WHERE ss.CompanyId = @CompanyId
        AND jl.IsDeleted = 0
END
GO

CREATE PROCEDURE [dbo].[SalaryStructure_Insert]
(
    @CompanyId SMALLINT
	,@Name NVARCHAR(255)
	,@JobLevelId INT
    ,@LocalSalary VARCHAR(100)
    ,@ExpatSalary VARCHAR(100)
	,@CreatedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 202507040@Tim
    Task: create salary structure
    DB: bodb_HRM

    Revisions:
        20250704@Tim: init [Redmine: #230542]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @SalaryStructureId INT
		,@xml XML
		,@logData NVARCHAR(MAX)

	IF EXISTS (
		SELECT 1
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE CompanyId = @CompanyId
            AND [Name] = @Name
            AND JobLevelId = @JobLevelId
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The salary structure already exists.'

		RETURN
	END
	
	INSERT INTO dbo.SalaryStructure (
		CompanyId
		,[Name]
		,JobLevelId
		,LocalSalary
		,ExpatSalary
		,[IsActive]
		,CreatedBy
		,CreatedDate
		)
	VALUES (
		@CompanyId
		,@Name
		,@JobLevelId
		,@LocalSalary
		,@ExpatSalary
		,1
		,@CreatedBy
		,GETDATE()
		)

    SELECT @SalaryStructureId = SCOPE_IDENTITY()

    SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
		    ,JobLevelId AS '@JobLevelId'
		    ,LocalSalary AS '@LocalSalary'
		    ,ExpatSalary AS '@ExpatSalary'
		FROM dbo.SalaryStructure WITH (NOLOCK)
		WHERE SalaryStructureId = @SalaryStructureId
		FOR XML PATH('Row')
			,TYPE
		)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @CreatedBy
		,@ObjectTypeId = 4
		,@ObjectId = @SalaryStructureId
		,@OldData = NULL
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END
GO