/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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