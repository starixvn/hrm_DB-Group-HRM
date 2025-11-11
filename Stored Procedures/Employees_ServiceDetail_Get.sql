/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employees_ServiceDetail_Get]
(
    @CompanyId INT
)
AS
/*
    Created: Jay.Do@2025-05-15
    Task: Get all employees service detail in company
    DB: bodb_HRM

    Revisions:
		20250812@Mira: change DB structure [Redmine: #235678]
		20251110@Jay.Do: get more props [Redmine: #243413]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @JoinedDateRuleType INT = 2;

	SELECT ce.EmpId,
        CASE 
            WHEN s.[Value] = @JoinedDateRuleType THEN 0
            WHEN es.IsLocal = 1 THEN ISNULL(g.LocalBasicAnnualLeaveBalance, 0)
            ELSE ISNULL(g.ExpatBasicAnnualLeaveBalance, 0)
        END AS AnnualLeave,
		JoinedDate,
		ConfirmedDate,
		es.WorkingDays,
		IsLocal,
        CASE 
            WHEN s.[Value] = @JoinedDateRuleType THEN 0
            WHEN es.IsLocal = 1 THEN ISNULL(g.LocalYearsOfServiceForExtraLeave, 0)
            ELSE ISNULL(g.ExpatYearsOfServiceForExtraLeave, 0)
        END AS ExtraLeaveForYearsOfService,
		MilitaryFromDate,
		MilitaryToDate
	FROM dbo.EmployeeSummary AS es WITH (ROWLOCK, UPDLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = es.EmpId
			AND ISNULL(ce.isDeleted, 0) = 0
			AND ce.[Enabled] = 1
		INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON e.UserId = ce.UserId 
			AND e.ResignedDate IS NULL
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupId = g.GroupId 
			AND g.CompanyId = @CompanyId
		LEFT JOIN dbo.[SystemConfigs] s (NOLOCK) ON ce.CompanyId = s.CompanyId 
			AND [Key] = 'AnnualLeaveResetTimeLine'
	WHERE e.JoinedDate IS NOT NULL
        AND (
            s.[Value] = @JoinedDateRuleType
            OR (
                (es.IsLocal = 1 AND ISNULL(g.LocalBasicAnnualLeaveBalance, 0) > 0)
                OR
                (es.IsLocal = 0 AND ISNULL(g.ExpatBasicAnnualLeaveBalance, 0) > 0)
            )
        );
END