/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE PROCEDURE [dbo].[EmployeePayroll_Import]
    @employeeListJson VARCHAR(MAX),
    @Month DATE,
    @PeriodType TINYINT,
    @ActorId INT = NULL,
	@CompanyId INT,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg VARCHAR(200) = '' OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Create temporary table to hold the JSON data
    DECLARE @EmployeeCosts TABLE (
        EmpId INT,
        PersonalCost MONEY,
        ExtraPayment MONEY
    );

    -- Parse JSON into temporary table
    INSERT INTO @EmployeeCosts (EmpId, PersonalCost, ExtraPayment)
    SELECT 
        EmpId,
        PersonalCost,
        ExtraPayment
    FROM OPENJSON(@employeeListJson)
    WITH (
        EmpId INT '$.EmpId',
        PersonalCost MONEY '$.TotalPersonalCost',
        ExtraPayment MONEY '$.ExtraPayment'
    );

    -- Update existing records
    UPDATE ep
    SET ep.PersonalCost = ec.PersonalCost,
        ep.ExtraPayment = ec.ExtraPayment,
        ep.ModifiedBy = @ActorId,
        ep.ModifiedDate = GETDATE()
    FROM [dbo].[EmployeePayroll] ep
	INNER JOIN [dbo].[CompanyEmployee] empCom ON ep.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
    INNER JOIN @EmployeeCosts ec ON ep.EmpId = ec.EmpId
    WHERE ep.Month = @Month 
    AND ep.PeriodType = @PeriodType;

    -- Insert new records
    INSERT INTO [dbo].[EmployeePayroll]
        ([EmpId]
        ,[PeriodType]
        ,[Month]
        ,[PersonalCost]
        ,[ExtraPayment]
        ,[CreatedBy]
        ,[CreatedDate]
        ,[ModifiedBy]
        ,[ModifiedDate])
    SELECT 
        ec.EmpId,
        @PeriodType,
        @Month,
        ec.PersonalCost,
        ec.ExtraPayment,
        @ActorId,
        GETDATE(),
        @ActorId,
        GETDATE()
    FROM @EmployeeCosts ec
	INNER JOIN [dbo].[CompanyEmployee] empCom ON ec.EmpId = empCom.EmpId AND empCom.CompanyId = @CompanyId
    LEFT JOIN [dbo].[EmployeePayroll] ep ON ec.EmpId = ep.EmpId
        AND ep.Month = @Month
        AND ep.PeriodType = @PeriodType
    WHERE ep.EmpId IS NULL;

END
