USE [bodb_HRM]
GO

/****** Object:  Table [dbo].[SalaryUploadHistory] ******/
CREATE TABLE [dbo].[SalaryUploadHistory](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[FileName] varchar(200) NOT NULL,
	[SavedFileName] varchar(200) NOT NULL,
	[CreatedBy] int NULL,
	[CreatedDate] datetime NULL,
	[PeriodType] tinyint NOT NULL,
	[Month] date NOT NULL,
	[CompanyId] int NOT NULL,
 CONSTRAINT [PK_SalaryUploadHistory] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[PersonalCost] ******/
CREATE TABLE [dbo].[EmployeePayroll](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EmpId] [int] NOT NULL,
	[PeriodType] [tinyint] NOT NULL,
	[Month] [date] NOT NULL,
	[PersonalCost] [money] NULL,
	[ExtraPayment] [money] NULL,
	[CreatedBy] [int] NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[ModifiedBy] [int] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL,
	CONSTRAINT [PK_EmployeePayroll] PRIMARY KEY CLUSTERED 
	(
		[Id] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
	CONSTRAINT [UQ_EmployeePayroll_EmpId_Month_PeriodType] UNIQUE ([EmpId], [Month], [PeriodType]),
	INDEX [IX_EmployeePayroll_EmpId_Month_PeriodType] ([EmpId], [Month], [PeriodType])
) ON [PRIMARY]
GO


/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[EmployeePayroll_Import]
    @employeeListJson VARCHAR(MAX),
    @Month DATE,
    @PeriodType TINYINT,
    @ActorId INT = NULL,
    @CompanyId INT,
    @SavedFileName VARCHAR(200),
    @FileName VARCHAR(200),
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
    Created: 20250505@Hank.Nguyen
    Task: Import employee payroll.
    DB: SMS-HRM
    Original: 

    Revisions:  
        Hank.Nguyen@20250505: Import employee payroll.
    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

    -- Constants
    DECLARE @FirstHalfPeriodType TINYINT = 1;
    DECLARE @SecondHalfPeriodType TINYINT = 2;
    DECLARE @FullMonthPeriodType TINYINT = 3;

    -- Temporary table for employee costs
    DECLARE @EmployeeCosts TABLE (
        EmpCode VARCHAR(200),
        PersonalCost MONEY,
        ExtraPayment MONEY
    );

    -- Parse JSON input
    INSERT INTO @EmployeeCosts (EmpCode, PersonalCost, ExtraPayment)
    SELECT 
        EmpCode,
        PersonalCost,
        ExtraPayment
    FROM OPENJSON(@employeeListJson)
    WITH (
        EmpCode VARCHAR(200) '$.EmpCode',
        PersonalCost MONEY '$.TotalPersonalCost',
        ExtraPayment MONEY '$.ExtraPayment'
    );

    -- Check if employee costs table is empty
    IF NOT EXISTS (SELECT 1 FROM @EmployeeCosts)
    BEGIN
        SET @ErrCode = 1;
        SET @ErrMsg = 'No employee payroll data found. Please check the input data.';
        RETURN;
    END

    -- Handle period type changes
    IF @PeriodType = @FullMonthPeriodType
    BEGIN
        -- Delete half-month records when switching to full month
        DELETE ep
        FROM [dbo].[EmployeePayroll] ep
        INNER JOIN [dbo].[CompanyEmployee] empCom 
            ON ep.EmpId = empCom.EmpId 
            AND empCom.CompanyId = @CompanyId
        WHERE ep.[Month] = @Month
        AND ep.PeriodType IN (@FirstHalfPeriodType, @SecondHalfPeriodType);
    END
    ELSE 
    BEGIN
        -- Delete full month records when switching to half month
        DELETE ep
        FROM [dbo].[EmployeePayroll] ep
        INNER JOIN [dbo].[CompanyEmployee] empCom 
            ON ep.EmpId = empCom.EmpId 
            AND empCom.CompanyId = @CompanyId
        WHERE ep.[Month] = @Month
        AND ep.PeriodType = @FullMonthPeriodType;
    END

    -- Update existing records
    UPDATE ep
    SET ep.PersonalCost = ISNULL(tmp.PersonalCost, ep.PersonalCost),
        ep.ExtraPayment = ISNULL(tmp.ExtraPayment, ep.ExtraPayment),
        ep.ModifiedBy = @ActorId,
        ep.ModifiedDate = GETDATE()
    FROM [dbo].[EmployeePayroll] ep
    INNER JOIN [dbo].[Employee] emp ON ep.EmpId = emp.EmpId
    INNER JOIN [dbo].[CompanyEmployee] empCom ON emp.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
    INNER JOIN @EmployeeCosts tmp ON emp.Code = tmp.EmpCode
    WHERE ep.Month = @Month
    AND ep.PeriodType = @PeriodType;

    -- Insert new records
    INSERT INTO [dbo].[EmployeePayroll]
    (
        [EmpId],
        [PeriodType],
        [Month],
        [PersonalCost],
        [ExtraPayment],
        [CreatedBy],
        [CreatedDate],
        [ModifiedBy],
        [ModifiedDate]
    )
    SELECT 
        emp.EmpId,
        @PeriodType,
        @Month,
        ISNULL(tmp.PersonalCost, 0),
        ISNULL(tmp.ExtraPayment, 0),
        @ActorId,
        GETDATE(),
        @ActorId,
        GETDATE()
    FROM @EmployeeCosts tmp
    INNER JOIN [dbo].[Employee] emp ON tmp.EmpCode = emp.Code
    INNER JOIN [dbo].[CompanyEmployee] empCom ON emp.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
    LEFT JOIN [dbo].[EmployeePayroll] ep ON emp.EmpId = ep.EmpId AND ep.Month = @Month AND ep.PeriodType = @PeriodType
    WHERE ep.EmpId IS NULL;

    -- Delete records not in import
    DELETE ep
    FROM [dbo].[EmployeePayroll] ep
    INNER JOIN [dbo].[Employee] emp ON ep.EmpId = emp.EmpId
    INNER JOIN [dbo].[CompanyEmployee] empCom ON emp.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
    LEFT JOIN @EmployeeCosts tmp ON emp.Code = tmp.EmpCode
    WHERE ep.[Month] = @Month
        AND ep.PeriodType = @PeriodType
        AND tmp.EmpCode IS NULL;

    -- Record upload history
    INSERT INTO [SalaryUploadHistory]
    (
        [FileName],
        [SavedFileName],
        [CreatedBy],
        [CreatedDate],
        [PeriodType],
        [Month],
        [CompanyId]
    )
    VALUES
    (
        @FileName,
        @SavedFileName,
        @ActorId,
        GETDATE(),
        @PeriodType,
        @Month,
        @CompanyId
    );

    SET @ErrMsg = 'Uploaded Salary successfully';

END

GO


/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[EmployeePayroll_Get]
    @Month DATE = NULL,
    @CompanyId INT,
	@PeriodType INT = NULL
AS
/*
	Created: 20250505@Hank.Nguyen
	Task: Import employee payroll.
	DB: SMS-HRM
	Original: 

	Revisions:  
		Hank.Nguyen@20250505: Import employee payroll.
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

    SELECT 
        ep.[EmpId],
        emp.[Code],
        emp.[FullName],
        emp.[NickName],
        dept.[Name] AS DepartmentName,
        team.[Name] AS TeamName,
        ep.[Month],
        ep.[PersonalCost],
        ep.[ExtraPayment],
        ep.[ModifiedDate] AS LastModifiedDate,
        ep.[PeriodType]
    FROM [dbo].[EmployeePayroll] ep WITH (NOLOCK)
    INNER JOIN [dbo].[Employee] emp WITH (NOLOCK) ON ep.EmpId = emp.EmpId
    INNER JOIN [dbo].[CompanyEmployee] empCom WITH (NOLOCK) ON emp.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
    LEFT JOIN [dbo].[Group] team WITH (NOLOCK) ON emp.GroupId = team.GroupId
    LEFT JOIN [dbo].[Department] dept WITH (NOLOCK) ON team.DepartmentId = dept.DepartmentId
    WHERE (@Month IS NULL OR ep.[Month] = @Month) AND
		(@PeriodType IS NULL OR ep.PeriodType = @PeriodType)
    ORDER BY ep.[Month], ep.[PeriodType], dept.[Name], team.[Name], emp.[FullName];

END

GO


/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[EmployeePayroll_ConfirmUpload]
    @Month DATE,
    @PeriodType TINYINT,
    @CompanyId INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
    Created: 20250505@Hank.Nguyen
    Task: Import employee payroll.
    DB: SMS-HRM
    Original: 

    Revisions:  
        Hank.Nguyen@20250505: Import employee payroll.
    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

    -- Constants
    DECLARE @FirstHalfPeriodType TINYINT = 1;
    DECLARE @SecondHalfPeriodType TINYINT = 2;
    DECLARE @FullMonthPeriodType TINYINT = 3;

    -- Check for conflicting records based on period type
    DECLARE @ConflictingRecordsExist BIT = 0;
    DECLARE @ConflictMessage VARCHAR(200);

    IF @PeriodType = @FullMonthPeriodType
    BEGIN
        SELECT @ConflictingRecordsExist = CASE 
            WHEN EXISTS (
                SELECT 1
                FROM [dbo].[EmployeePayroll] ep
                INNER JOIN [dbo].[CompanyEmployee] empCom 
                    ON ep.EmpId = empCom.EmpId 
                    AND empCom.CompanyId = @CompanyId
                WHERE ep.[Month] = @Month
                    AND ep.PeriodType IN (@FirstHalfPeriodType, @SecondHalfPeriodType)
            ) THEN 1 ELSE 0 END;
        
        SET @ConflictMessage = 'Half-month records exist. Do you want to replace them with full month salary?';
    END
    ELSE 
    BEGIN
        SELECT @ConflictingRecordsExist = CASE
            WHEN EXISTS (
                SELECT 1
                FROM [dbo].[EmployeePayroll] ep
                INNER JOIN [dbo].[CompanyEmployee] empCom 
                    ON ep.EmpId = empCom.EmpId 
                    AND empCom.CompanyId = @CompanyId
                WHERE ep.[Month] = @Month
                    AND ep.PeriodType = @FullMonthPeriodType
            ) THEN 1 ELSE 0 END;

        SET @ConflictMessage = 'Full-month records exist. Do you want to replace them with half month salary?';
    END

    -- Set output parameters based on conflict check
    IF @ConflictingRecordsExist = 1
    BEGIN
        SET @ErrCode = 1;
        SET @ErrMsg = @ConflictMessage;
        RETURN;
    END

    SET @ErrMsg = 'No conflicts found. You can proceed with the upload.';
END

GO


/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[SalaryUploadHistory_Get]
    @CompanyId INT
AS
/*
	Created: 20250505@Hank.Nguyen
	Task: Get salary upload history.
	DB: SMS-HRM
	Original: 

	Revisions:  
		Hank.Nguyen@20250505: Get salary upload history.
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;

    SELECT 
        su.[FileName],
        su.[SavedFileName],
        su.[CreatedBy],
        su.[CreatedDate],
        su.[PeriodType],
        su.[Month],
        emp.[NickName]  
    FROM [dbo].[SalaryUploadHistory] su
    LEFT JOIN [dbo].[Employee] emp ON su.CreatedBy = emp.EmpId
    WHERE su.[CompanyId] = @CompanyId
    ORDER BY su.[CreatedDate] DESC;

END
GO









