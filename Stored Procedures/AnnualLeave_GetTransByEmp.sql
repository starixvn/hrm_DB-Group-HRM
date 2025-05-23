/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[AnnualLeave_GetTransByEmp] @EmpId INT
	,@fromDate DATETIME
	,@excludedRequestTrans BIT
AS
/*
Created: Tom.Vo@2013.10.22
Task: show annual leave tranasaction by employee
DB: HRM
Original:

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @fromdateRange DATETIME
		,@todateRange DATETIME
		,@CompanyId SMALLINT
        ,@JoinedDate DATE
		,@AnnualLeaveResetTimelineType TINYINT
		,@AnnualLeaveResetTimelineByYear TINYINT = 1

		SELECT @CompanyId = ce.CompanyId
        ,@JoinedDate = e.JoinedDate
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
    WHERE e.EmpId = @EmpId

	 SELECT @AnnualLeaveResetTimelineType = [Value]
    FROM dbo.SystemConfigs WITH (NOLOCK)
    WHERE CompanyId = @CompanyId
        AND [Key] = 'AnnualLeaveResetTimeline'

    IF @AnnualLeaveResetTimelineType = @AnnualLeaveResetTimelineByYear
    BEGIN
        SET @fromdateRange = DATEFROMPARTS(YEAR(@fromDate), 1, 1)
    END
    ELSE
    BEGIN
        SET @fromdateRange = DATEFROMPARTS(YEAR(@fromDate), MONTH(@JoinedDate), DAY(@JoinedDate))
		
        IF @fromDate < @fromdateRange
        BEGIN
            SET @fromdateRange = DATEADD(YEAR, -1, @fromdateRange)
        END
    END

	SET @todateRange = DATEADD(YEAR, 1, @fromdateRange)
	

	SELECT t.LeaveTransId
		,RequestId
		,FromDate AS AffectedFrom
		,ISNULL(CreditDays, 0) - ISNULL(DeductDays, 0) AS [ToTalDays]
		,[Description]
		,ISNULL(t.ModifiedDate, t.CreatedDate) AS ModifiedDate
	FROM dbo.LeaveTrans t WITH (NOLOCK)
		INNER JOIN dbo.Employee e WITH (NOLOCK) ON e.EmpID = t.EmpId
	WHERE FromDate >= @fromdateRange
		AND FromDate < @todateRange
		AND (ISNULL(ExtraDays, 0) = 0 OR (ExtraDays > 0 AND CreditDays > 0))
		AND t.EmpId = @EmpId
		AND ISNULL(Deleted, 0) = 0
		AND (
			@excludedRequestTrans = 0
			OR RequestId IS NULL
			)
END
