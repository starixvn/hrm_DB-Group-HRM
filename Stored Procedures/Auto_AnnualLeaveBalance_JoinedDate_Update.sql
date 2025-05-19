/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Auto_AnnualLeaveBalance_JoinedDate_Update]
(
	@ListAnnualLeaveJson NVARCHAR(MAX)
)
AS
/*
    Created: Jay.Do@2025-05-16
    Task: Update annual leave balance for company count from joined date
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Description NVARCHAR(100) = 'Create annual balance leave for employees count from joined date.';

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
              AND lt.Deleted = 0
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
		,DATEADD(YEAR, t.[Year] - YEAR(JoinedDate), JoinedDate) as FromDate
		,DATEADD(DAY, -1, DATEADD(YEAR, t.[Year] - YEAR(JoinedDate) + 1, JoinedDate)) as ToDate
		,0 AS DeductDays
		,t.AnnualLeaves AS CreditDays
		,t.ExtraLeaves AS ExtraDays
		,GETDATE()
		,0 AS Deleted
	FROM @TempListAnnualLeaves AS t
		INNER JOIN Employee e ON e.EmpId = t.EmpId
	WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.LeaveTrans AS lt WITH (NOLOCK)
        WHERE t.EmpId = lt.EmpId
              AND YEAR(lt.FromDate) = t.[Year]
              AND lt.DeductDays = 0
              AND lt.CreditDays > 0
              AND lt.RequestId IS NULL
              AND lt.Deleted = 0
    )
END