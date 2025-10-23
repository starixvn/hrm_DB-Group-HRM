/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[EmployeePayroll_Upsert]
(
    @EmpId INT,
    @SalaryStructureId INT = NULL,
    @SpecialSubsidy VARCHAR(100) = NULL,
    @NoOfDependent INT = 0,
    @AllowanceItemSettingIds NVARCHAR(MAX) = NULL,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Henry
    Task: Update or Insert EmployeePayroll record
    DB: bodb_HRM

    Revisions:
        - 20251017@Henry: create separate SP for payroll operations [Redmine: #241812]
    
    Param's Explanation:
        @EmpId - Employee ID
        @SalaryStructureId - Salary Structure ID (optional)
        @SpecialSubsidy - Special Subsidy amount (encrypted, optional)
        @NoOfDependent - Number of dependents (default 0)
        @AllowanceItemSettingIds - Comma-separated list of AllowanceItemSettingId values to assign to employee
        @ModifiedBy - User ID who modified the record
        @ErrCode - Error code output
        @ErrMsg - Error message output
*/
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @SalaryStructureId IS NOT NULL OR @SpecialSubsidy IS NOT NULL OR @NoOfDependent > 0
        BEGIN
            MERGE [dbo].[EmployeePayroll] AS target
            USING (SELECT @EmpId AS EmpId, @SalaryStructureId AS SalaryStructureId, @SpecialSubsidy AS SpecialSubsidy, @NoOfDependent AS NoOfDependent) AS source
            ON target.[EmpId] = source.[EmpId]
            WHEN MATCHED THEN
                UPDATE SET 
                    [SalaryStructureId] = ISNULL(source.[SalaryStructureId], target.[SalaryStructureId]),
                    [SpecialSubsidy] = ISNULL(source.[SpecialSubsidy], target.[SpecialSubsidy]),
                    [NoOfDependent] = ISNULL(source.[NoOfDependent], target.[NoOfDependent])
            WHEN NOT MATCHED THEN
                INSERT ([EmpId], [SalaryStructureId], [SpecialSubsidy], [NoOfDependent])
                VALUES (source.[EmpId], source.[SalaryStructureId], source.[SpecialSubsidy], source.[NoOfDependent]);
        END

        DECLARE @NewAllowances TABLE (
            AllowanceItemSettingId INT
        );

        IF @AllowanceItemSettingIds IS NOT NULL AND @AllowanceItemSettingIds != ''
        BEGIN
            INSERT INTO @NewAllowances (AllowanceItemSettingId)
            SELECT CAST(value AS INT) AS AllowanceItemSettingId
            FROM STRING_SPLIT(@AllowanceItemSettingIds, ',')
            WHERE value IS NOT NULL AND value != '';
        END

        DELETE FROM [dbo].[EmployeePayrollAllowance] 
        WHERE [EmpId] = @EmpId;

        IF EXISTS (SELECT 1 FROM @NewAllowances)
        BEGIN
            INSERT INTO [dbo].[EmployeePayrollAllowance] ([EmpId], [AllowanceItemSettingId])
            SELECT @EmpId, AllowanceItemSettingId
            FROM @NewAllowances;
        END
    END TRY
    BEGIN CATCH
        SET @ErrCode = ERROR_NUMBER();
        SET @ErrMsg = ERROR_MESSAGE();
        
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
    END CATCH
END
