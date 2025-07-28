USE [bodb_HRM]
GO
/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE SubCompanies_ByCompanyId_Get
	@CompanyId INT = NULL
AS
/*
Created: 20250616@Jay
Task: Get all subcompanies by company id
DB: bodb_HRM
Original:

Revisions:
	20250723@Lilac:  Get all sub companies when companyId null
*/
BEGIN
	SET NOCOUNT ON;

	SELECT SubCompanyId,
		CompanyId,
		[Name]
	FROM SubCompany
	WHERE (@CompanyId IS NULL OR CompanyId = @CompanyId)
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[SystemConfigs_Update]
    @CompanyId INT,
    @SettingsJson NVARCHAR(MAX),
    @ModifiedBy INT,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg VARCHAR(200) = '' OUTPUT
AS

/*
Created: 20250717@Lilac.Nguyen
Task: Update Setting Companys
DB: bodb_HRM
Original:

Revisions:
	20250725@Lilac.Nguyen: write log

*/

BEGIN
    SET NOCOUNT ON;

    DECLARE @Configs TABLE (
        [Key] VARCHAR(100),
        [Value] VARCHAR(MAX)
    );

    DECLARE @xml XML;
    DECLARE @logOldData NVARCHAR(MAX) = NULL;
    DECLARE @logData NVARCHAR(MAX) = NULL;
	DECLARE @InsertedKeys TABLE (
        [Key] VARCHAR(100)
    );

    INSERT INTO @Configs ([Key], [Value])
    SELECT [Key], [Value]
    FROM OPENJSON(@SettingsJson);

    SET @xml = (
        SELECT sc.[Key] AS '@Key',
               sc.[Value] AS '@Value'
        FROM dbo.SystemConfigs sc WITH (NOLOCK)
        JOIN @Configs cfg ON cfg.[Key] = sc.[Key]
        WHERE sc.CompanyId = @CompanyId
          AND ISNULL(sc.[Value], '') <> ISNULL(cfg.[Value], '')
        FOR XML PATH('Row'), TYPE
    );
    SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

    UPDATE sc
    SET sc.[Value] = cfg.[Value]
    FROM dbo.SystemConfigs sc
    JOIN @Configs cfg ON cfg.[Key] = sc.[Key]
    WHERE sc.CompanyId = @CompanyId
      AND ISNULL(sc.[Value], '') <> ISNULL(cfg.[Value], '');

    SET @xml = (
        SELECT sc.[Key] AS '@Key',
               sc.[Value] AS '@Value'
        FROM dbo.SystemConfigs sc WITH (NOLOCK)
        JOIN @Configs cfg ON cfg.[Key] = sc.[Key]
        WHERE sc.CompanyId = @CompanyId
          AND ISNULL(sc.[Value], '') = ISNULL(cfg.[Value], '')
        FOR XML PATH('Row'), TYPE
    );
    SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

    IF (@logOldData IS NOT NULL AND @logData IS NOT NULL)
    BEGIN
        EXEC dbo.ActivityLog_Insert 
            @UserId = @ModifiedBy,
            @ObjectTypeId = 5,
            @ObjectId = @CompanyId,
            @OldData = @logOldData,
            @Data = @logData,
            @ErrCode = @ErrCode OUTPUT,
            @ErrMsg = @ErrMsg OUTPUT;
    END

    INSERT INTO dbo.SystemConfigs (CompanyId, [Key], [Value])
    OUTPUT inserted.[Key] INTO @InsertedKeys([Key])
    SELECT @CompanyId, cfg.[Key], cfg.[Value]
    FROM @Configs cfg
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.SystemConfigs sc
        WHERE sc.CompanyId = @CompanyId AND sc.[Key] = cfg.[Key]
    );

    SET @xml = (
        SELECT sc.[Key] AS '@Key',
               sc.[Value] AS '@Value'
        FROM dbo.SystemConfigs sc WITH (NOLOCK)
        JOIN @InsertedKeys ik ON sc.[Key] = ik.[Key]
        WHERE sc.CompanyId = @CompanyId
        FOR XML PATH('Row'), TYPE
    );
    SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

    IF (@logData IS NOT NULL)
    BEGIN
        EXEC dbo.ActivityLog_Insert 
            @UserId = @ModifiedBy,
            @ObjectTypeId = 5,
            @ObjectId = @CompanyId,
            @OldData = NULL,
            @Data = @logData,
            @ErrCode = @ErrCode OUTPUT,
            @ErrMsg = @ErrMsg OUTPUT;
    END
END

GO
/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[SubCompany_CountEmployeeById]
(
    @CompanyId INT
)
AS
/*
    Created: 20250724@Lilac.Nguyen
    Task: count employee by company id
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT SubCompanyId, COUNT(*) AS EmployeeCount
	FROM CompanyEmployee
	WHERE CompanyId = @CompanyId 
	  AND ISNULL(IsDeleted, 0) <> 1
	  AND SubCompanyId IS NOT NULL
	GROUP BY SubCompanyId

END

GO

CREATE OR ALTER PROCEDURE [dbo].[SubCompany_Insert] @CompanyId INT
	,@Name NVARCHAR(100)
	,@CreatedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20250724@Lilac.Nguyen
Task: insert sub company
DB: bodb_HRM
Original: 

Revisions:  

Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
    DECLARE @SubCompanyId INT
		,@xml XML
		,@logData NVARCHAR(MAX)

	IF EXISTS (
			SELECT 1
			FROM dbo.SubCompany WITH (NOLOCK)
			WHERE CompanyId = @CompanyId 
				AND [Name] = @Name
				AND IsActivated = 1
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The sub company ' + CONVERT(NVARCHAR(100), @Name) + ' has already exists.'

		RETURN
	END

	INSERT INTO dbo.SubCompany (
			CompanyId,
			[Name],
			CountryCode,
			IsActivated,
			ModifiedBy,
			ModifiedDate
		)
		VALUES (
			@CompanyId,
			@Name,
			NULL,
			1,
			@CreatedBy,
			GETDATE()
		)

	SELECT @SubCompanyId = SCOPE_IDENTITY()

	SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
			,SubCompanyId AS '@SubCompanyId'
		FROM dbo.SubCompany WITH (NOLOCK)
		WHERE SubCompanyId = @SubCompanyId
		FOR XML PATH('Row'), TYPE
		)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @CreatedBy
		,@ObjectTypeId = 6
		,@ObjectId = @SubCompanyId
		,@OldData = NULL
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

END;

GO
/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[SubCompany_Update] @CompanyId INT
	,@SubCompanyId INT
	,@Name NVARCHAR(100)
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20250724@Lilac.Nguyen
Task: update sub company
DB: bodb_HRM
Original: 

Revisions:  

Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
    DECLARE @xml XML
		,@logData NVARCHAR(MAX)
        ,@logOldData NVARCHAR(MAX)

	IF EXISTS (
			SELECT 1
			FROM dbo.SubCompany WITH (NOLOCK)
			WHERE CompanyId = @CompanyId 
				AND [Name] = @Name
				AND (@SubCompanyId IS NULL OR SubCompanyId <> @SubCompanyId)
				AND IsActivated = 1
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The sub company ' + CONVERT(NVARCHAR(100), @Name) + ' has already exists.'

		RETURN
	END

	SET @xml = (
			SELECT CompanyId AS '@CompanyId'
				,[Name] AS '@Name'
				,SubCompanyId AS '@SubCompanyId'
			FROM dbo.SubCompany WITH (NOLOCK)
			WHERE SubCompanyId = @SubCompanyId
			FOR XML PATH('Row'), TYPE
			)

		SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

		UPDATE dbo.SubCompany WITH (ROWLOCK, UPDLOCK)
		SET [Name] = @Name
			,[ModifiedBy] = @ModifiedBy
			,[ModifiedDate] = GETDATE()
		WHERE CompanyId = @CompanyId AND SubCompanyId = @SubCompanyId

	SET @xml = (
        SELECT CompanyId AS '@CompanyId'
		    ,[Name] AS '@Name'
			,SubCompanyId AS '@SubCompanyId'
		FROM dbo.SubCompany WITH (NOLOCK)
		WHERE SubCompanyId = @SubCompanyId
		FOR XML PATH('Row'), TYPE
		)
	SET @logData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	EXEC dbo.ActivityLog_Insert @UserId = @ModifiedBy
		,@ObjectTypeId = 6
		,@ObjectId = @SubCompanyId
		,@OldData = @logOldData
		,@Data = @logData
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

END;

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[SubCompany_Delete]
	@SubCompanyId INT
	,@DeletedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
    Created: 20250724@Lilac.Nguyen
    Task: delete sub company
    DB: bodb_HRM

    Revisions:

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @xml XML
        ,@logOldData NVARCHAR(MAX)

	IF EXISTS (
		SELECT 1
		FROM dbo.CompanyEmployee WITH (NOLOCK)
		WHERE SubCompanyId = @SubCompanyId
		)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The sub company cannot be deleted because it is already in use.'

		RETURN
	END

	SET @xml = (
				SELECT CompanyId AS '@CompanyId'
					,[Name] AS '@Name'
					,SubCompanyId AS '@SubCompanyId'
				FROM dbo.SubCompany WITH (NOLOCK)
				WHERE SubCompanyId = @SubCompanyId
				FOR XML PATH('Row'), TYPE
				)

	SET @logOldData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	
	DELETE dbo.SubCompany WITH (ROWLOCK)
    WHERE SubCompanyId = @SubCompanyId

	EXEC dbo.ActivityLog_Insert @UserId = @DeletedBy
		,@ObjectTypeId = 6
		,@ObjectId = @SubCompanyId
		,@OldData = @logOldData
		,@Data = NULL
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
    ,@Salary VARCHAR(100) = NULL
    ,@AutoApproveRequest BIT = 0
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
				,sc.[Name] AS '@SubCompanyName'
                ,ce.SalaryStructureId AS '@SalaryStructureId'
                ,ce.Salary AS '@Salary'
                ,ce.AutoApproveRequest AS '@AutoApproveRequest'
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
				INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
					AND ce.CompanyId = @CompanyId
				LEFT JOIN dbo.SubCompany AS sc WITH (NOLOCK) ON sc.SubCompanyId = ce.SubCompanyId AND sc.CompanyId = ce.CompanyId
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
        ,AutoApproveRequest = @AutoApproveRequest
	WHERE EmpId = @EmpId
        AND CompanyId = @CompanyId

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
				,sc.[Name] AS '@SubCompanyName'
                ,ce.SalaryStructureId AS '@SalaryStructureId'
                ,ce.Salary AS '@Salary'
                ,ce.AutoApproveRequest AS '@AutoApproveRequest'
			FROM dbo.Employee AS emp WITH (NOLOCK)
				INNER JOIN dbo.EmployeeSummary AS empsum WITH (NOLOCK) ON emp.EmpId = empsum.EmpId
				INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON emp.EmpId = ce.EmpId
					AND ce.CompanyId = @CompanyId
				LEFT JOIN dbo.SubCompany AS sc WITH (NOLOCK) ON sc.SubCompanyId = ce.SubCompanyId AND sc.CompanyId = ce.CompanyId
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