/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Overtime_GetMonthlyRequestByEmpId] @EmployeeId INT,
	@FromDate DATE,
	@ToDate DATE,
	@CompanyId SMALLINT
AS
/*
Created: Tim.Trinh@2019-07-02
Task: get monthly overtime
DB: HRM

Revisions:
	- Jay.do@20250603: handle cross company [Redmine: #227151]
	- Mira@20250716: remove company with nick name for employee in different company [#Redmine: 232030]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATE = GETDATE()
		,@tmpFromDate DATE = @FromDate

	CREATE TABLE #tblMonth ([Month] DATE)

	WHILE @tmpFromDate <= @toDate
	BEGIN
		INSERT INTO #tblMonth ([Month])
		VALUES (@tmpFromDate)

		SET @tmpFromDate = DATEADD(MONTH, 1, @tmpFromDate)
	END

	SELECT request.RequestId
		,cl.[Month]
		,request.VerifiedDate
		,request.ApprovedDate
		,request.NormalHours
		,request.OffHours
		,request.PublicHours
		,request.SpecialHours
		,request.CurrentStatus AS StatusId
		,vece.EmpId AS VerifierId
		,vece.NickName
		,verifier.FullName
		,apce.EmpId AS ApproverId
		,apce.NickName
		,approver.FullName
	FROM #tblMonth AS cl
		LEFT JOIN dbo.OTMonthlyRequest AS request WITH (NOLOCK) ON request.[Month] = cl.[Month]
		AND request.[Month] BETWEEN @fromdate
			AND @todate
		AND request.EmpId = @EmployeeId
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.EmpId = request.EmpId
		LEFT JOIN dbo.Employee AS emp WITH (NOLOCK) ON emp.UserId = ce.UserId
		LEFT JOIN dbo.CompanyEmployee AS vece WITH (NOLOCK) ON vece.EmpId = request.VerifierId
		LEFT JOIN dbo.Employee AS verifier WITH (NOLOCK) ON verifier.UserId = vece.UserId
		LEFT JOIN dbo.CompanyEmployee AS apce WITH (NOLOCK) ON apce.EmpId = request.ApproverId
		LEFT JOIN dbo.Employee AS approver WITH (NOLOCK) ON approver.UserId = apce.UserId
		LEFT JOIN dbo.Company vec WITH (NOLOCK) ON vec.CompanyId = vece.CompanyId
		LEFT JOIN dbo.Company apc WITH (NOLOCK) ON apc.CompanyId = apce.CompanyId
	    AND ce.CompanyId = @CompanyId
	WHERE EXISTS (
			SELECT 1
			FROM dbo.EmployeeSummary WITH (NOLOCK)
			WHERE EmpId = @EmployeeId
				AND CanOT = 1
			)
	ORDER BY cl.[Month] DESC

	DROP TABLE #tblMonth
END