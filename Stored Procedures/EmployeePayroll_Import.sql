/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeePayroll_Import]
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
		20250812@Mira: change DB structure [Redmine: #235678]
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
    INNER JOIN [dbo].[CompanyEmployee] empCom ON ep.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
    INNER JOIN @EmployeeCosts tmp ON empCom.Code = tmp.EmpCode
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
        empCom.EmpId,
        @PeriodType,
        @Month,
        ISNULL(tmp.PersonalCost, 0),
        ISNULL(tmp.ExtraPayment, 0),
        @ActorId,
        GETDATE(),
        @ActorId,
        GETDATE()
    FROM @EmployeeCosts tmp
    INNER JOIN [dbo].[CompanyEmployee] empCom ON tmp.EmpCode = empCom.Code AND empCom.CompanyId = @CompanyId
    LEFT JOIN [dbo].[EmployeePayroll] ep ON empCom.EmpId = ep.EmpId AND ep.Month = @Month AND ep.PeriodType = @PeriodType
    WHERE ep.EmpId IS NULL;

    -- Delete records not in import
    DELETE ep
    FROM [dbo].[EmployeePayroll] ep
    INNER JOIN [dbo].[CompanyEmployee] empCom ON ep.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
    LEFT JOIN @EmployeeCosts tmp ON empCom.Code = tmp.EmpCode
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