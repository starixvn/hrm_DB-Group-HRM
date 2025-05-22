USE [bodb_HRM]
GO
IF NOT EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE Name = N'LocalYearsOfServiceForExtraLeave' 
      AND Object_ID = Object_ID(N'dbo.[Group]')
)
BEGIN
    ALTER TABLE dbo.[Group] 
    ADD LocalYearsOfServiceForExtraLeave INT;
END

IF NOT EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE Name = N'ExpatYearsOfServiceForExtraLeave' 
      AND Object_ID = Object_ID(N'dbo.[Group]')
)
BEGIN
    ALTER TABLE dbo.[Group] 
    ADD ExpatYearsOfServiceForExtraLeave INT;
END

DECLARE @AscentisId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'Ascentis')
DECLARE @HyjayId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'Hyjay')
DECLARE @LetstalkId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'Letstalk')
DECLARE @NextFortuneId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'Next Fortune')
DECLARE @OneLabId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'One Lab')
DECLARE @SSIId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'SSI')
DECLARE @EMCId INT = (SELECT CompanyId FROM dbo.Company WITH(NOLOCK) WHERE [Name] = 'EMC')
INSERT INTO SystemConfigs([Key], [Value], CompanyId)
VALUES('AnnualLeaveResetTimeLine', 2, @AscentisId),
('AnnualLeaveResetTimeLine', 2, @HyjayId),
('AnnualLeaveResetTimeLine', 2, @LetstalkId),
('AnnualLeaveResetTimeLine', 2, @NextFortuneId),
('AnnualLeaveResetTimeLine', 2, @OneLabId),
('AnnualLeaveResetTimeLine', 2, @SSIId),
('AnnualLeaveResetTimeLine', 2, @EMCId)

UPDATE dbo.[RefResource] 
SET [Value] = 1
WHERE CompanyId in (@AscentisId, @HyjayId, @LetstalkId, @NextFortuneId, @OneLabId, @SSIId, @EMCId)
	AND RefName = 'EnableAdditionalAnnualLeaveBalance'

DECLARE @SMSId INT = 3
DECLARE @HMId INT = 4
DECLARE @CabintechId INT = 9
DECLARE @ConnectshoreCorpId INT = 12
DECLARE @CymabellId INT = 13
DECLARE @DIGIBYTESKYId INT = 15
DECLARE @ElementStrategiesId INT = 16
DECLARE @LexfinId INT = 6
DECLARE @SandsdoverId INT = 26
DECLARE @XPCId INT = 28
DECLARE @DARId INT = 14
DECLARE @WGIId INT = 8
INSERT INTO SystemConfigs([Key], [Value], CompanyId)
VALUES('AnnualLeaveResetTimeLine', 1, @SMSId),
('AnnualLeaveResetTimeLine', 1, @HMId),
('AnnualLeaveResetTimeLine', 1, @CabintechId),
('AnnualLeaveResetTimeLine', 1, @ConnectshoreCorpId),
('AnnualLeaveResetTimeLine', 1, @CymabellId),
('AnnualLeaveResetTimeLine', 1, @DIGIBYTESKYId),
('AnnualLeaveResetTimeLine', 1, @ElementStrategiesId),
('AnnualLeaveResetTimeLine', 1, @LexfinId),
('AnnualLeaveResetTimeLine', 1, @SandsdoverId),
('AnnualLeaveResetTimeLine', 1, @XPCId),
('AnnualLeaveResetTimeLine', 1, @DARId),
('AnnualLeaveResetTimeLine', 1, @WGIId)
GO

ALTER TABLE bodb_HRM.dbo.LeaveTrans
ADD ExtraDays numberic(18,1) NULL
GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER   PROCEDURE [dbo].[AnnualLeave_ResetConfigs_Get]
AS
/*
    Created: Jay.Do@2025-05-15
    Task: Get all annual leave reset configs
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT sc.CompanyId,
		sc.[Value] AS Timeline,
		rr.[Value] AS EnableAdditionalAnnualLeaveBalance
	FROM dbo.[SystemConfigs] sc
	LEFT JOIN dbo.[RefResource] rr ON sc.CompanyId = rr.CompanyId 
		AND RefName = 'EnableAdditionalAnnualLeaveBalance'
	WHERE [Key] = 'AnnualLeaveResetTimeLine'
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER   PROCEDURE [dbo].[Auto_AnnualLeaveBalance_JoinedDate_Update]
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

	UPDATE lt
	SET lt.ExtraDays = t.ExtraLeaves
	FROM dbo.LeaveTrans AS lt WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @TempListAnnualLeaves AS t ON t.EmpId = lt.EmpId
	WHERE YEAR(lt.FromDate) = t.[Year]
		AND lt.DeductDays = 0
		AND lt.CreditDays > 0
		AND lt.RequestId IS NULL
		AND lt.Deleted = 0
		AND t.ExtraLeaves > 0
		AND (lt.ExtraDays = 0 OR lt.ExtraDays IS NULL)
END

GO

/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER   PROCEDURE [dbo].[Employees_ServiceDetail_Get]
(
    @CompanyId INT
)
AS
/*
    Created: Jay.Do@2025-05-15
    Task: Get all employees service detail in company
    DB: bodb_HRM

    Revisions:
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT e.EmpId,
		CASE 
			WHEN es.IsLocal = 1 THEN ISNULL(g.LocalBasicAnnualLeaveBalance, 0)
			ELSE ISNULL(g.ExpatBasicAnnualLeaveBalance, 0)
			END AS AnnualLeave,
		JoinedDate,
		es.WorkingDays,
		CASE 
			WHEN es.IsLocal = 1 THEN ISNULL(g.LocalYearsOfServiceForExtraLeave, 0)
			ELSE ISNULL(g.ExpatYearsOfServiceForExtraLeave, 0)
			END AS ExtraLeaveForYearsOfService
	FROM dbo.EmployeeSummary AS es WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.EmpId = es.EmpId
			AND ISNULL(e.isDeleted, 0) = 0
			AND e.[Enabled] = 1
			AND e.ResignedDate IS NULL
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId AND g.CompanyId = @CompanyId
	WHERE e.JoinedDate IS NOT NULL
		AND (
			(es.IsLocal = 1 AND ISNULL(g.LocalBasicAnnualLeaveBalance, 0) > 0)
			OR 
			(es.IsLocal = 0 AND ISNULL(g.ExpatBasicAnnualLeaveBalance, 0) > 0)
    )
END

GO