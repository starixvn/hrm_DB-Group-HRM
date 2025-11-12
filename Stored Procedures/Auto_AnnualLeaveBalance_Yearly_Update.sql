/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE   PROCEDURE [dbo].[Auto_AnnualLeaveBalance_Yearly_Update]
(
	@ListAnnualLeaveJson NVARCHAR(MAX)
)
AS
/*
    Created: Jay.Do@2025-11-11
    Task: Update annual leave balance for yearly companies
    DB: bodb_HRM

    Revisions:
		20251111@Jay.Do: count AL new flow [Redmine: #243413]
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Description NVARCHAR(100) = 'Create annual balance leave for employees count from yearly companies.';

	DECLARE @TempListAnnualLeaves TABLE (
		AnnualLeaves INT,
		ExtraLeaves INT,
		EmpId INT,
		[Year] INT
	)

	INSERT INTO @TempListAnnualLeaves
	SELECT DISTINCT
		j.AnnualLeaves,
		j.ExtraLeaves,
		j.EmpId,
		j.[Year]
	FROM OPENJSON(@ListAnnualLeaveJson)
	WITH (
		AnnualLeaves INT,
		ExtraLeaves INT,
		EmpId INT,
		[Year] INT
	) AS j
	WHERE j.AnnualLeaves > 0 

	UPDATE es
	SET es.AnnualLeaveBalance = ISNULL(es.AnnualLeaveBalance, 0) + t.AnnualLeaves + t.ExtraLeaves
	FROM dbo.EmployeeSummary AS es WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @TempListAnnualLeaves AS t ON t.EmpId = es.EmpId
	WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.LeaveTrans AS lt WITH (NOLOCK)
        WHERE es.EmpId = lt.EmpId
              AND YEAR(lt.FromDate) = t.[Year]
              AND lt.DeductDays = 0
              AND lt.CreditDays > 0
              AND lt.RequestId IS NULL
              AND ISNULL(lt.Deleted, 0) = 0
    )

	INSERT INTO dbo.LeaveTrans (
		EmpId
		,[Description]
		,FromDate
		,ToDate
		,DeductDays
		,CreditDays
		,ExtraDays
		,CreatedDate
		,Deleted
		)
	SELECT t.EmpId
		,@Description
		,DATEFROMPARTS(t.[Year], 1, 1) AS FromDate
		,DATEFROMPARTS(t.[Year], 12, 31) AS ToDate
		,0 AS DeductDays
		,t.AnnualLeaves AS CreditDays
		,t.ExtraLeaves AS ExtraDays
		,GETDATE()
		,0 AS Deleted
	FROM @TempListAnnualLeaves AS t
		INNER JOIN CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = t.EmpId
	WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.LeaveTrans AS lt WITH (NOLOCK)
        WHERE t.EmpId = lt.EmpId
              AND YEAR(lt.FromDate) = t.[Year]
              AND lt.DeductDays = 0
              AND lt.CreditDays > 0
              AND lt.RequestId IS NULL
              AND ISNULL(lt.Deleted, 0) = 0
    )

	UPDATE lt
	SET lt.ExtraDays = t.ExtraLeaves
	FROM dbo.LeaveTrans AS lt WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @TempListAnnualLeaves AS t ON t.EmpId = lt.EmpId
	WHERE YEAR(lt.FromDate) = t.[Year]
		AND lt.DeductDays = 0
		AND lt.CreditDays > 0
		AND lt.RequestId IS NULL
        AND ISNULL(lt.Deleted, 0) = 0
		AND t.ExtraLeaves > 0
		AND (lt.ExtraDays = 0 OR lt.ExtraDays IS NULL)
END