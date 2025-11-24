/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE dbo.[Report_HeadcountGetWFH] @Year INT

/*
Created: 20250219@Mira
Task : Group HRA report
DB: bodb_HRM	

Revisions:
	20250219@Mira: Get data for headcount report - [Redmine: #231008]
	20251120@Mira: Only get CountInHeadcount WFH emp [Redmine: #244781]
*/
AS 

BEGIN
	SET NOCOUNT ON;
	DECLARE @FromDate DATETIME = DATEFROMPARTS(@Year, 1, 1);
	DECLARE @ToDate DATETIME = DATEFROMPARTS(@Year, 12, 31);

	SELECT e.EmpId,
		e.FromDate,
		ISNULL(e.ToDate, @ToDate) 'ToDate'
	FROM dbo.EmployeeWorkFromHome e WITH (NOLOCK)
	WHERE e.FromDate <= @ToDate AND (e.ToDate IS NULL OR e.ToDate >= @FromDate) AND e.IsCountInHeadcount = 1
	-- Nexcel
	UNION 
	SELECT e.EmpId,
		e.FromDate,
		e.ToDate
	FROM NexHRM.dbo.WorkFromHomeRequest e WITH (NOLOCK)
	WHERE e.FromDate <= @ToDate AND e.ToDate >= @FromDate AND e.Status <> 3
	-- Lumi
	UNION 
	SELECT e.EmpId,
		e.FromDate,
		e.ToDate
	FROM LumiHRM.dbo.WorkFromHomeRequest e WITH (NOLOCK)
	WHERE e.FromDate <= @ToDate AND e.ToDate >= @FromDate AND e.Status <> 3
	-- NexVision
	UNION 
	SELECT e.EmpId,
		e.FromDate,
		e.ToDate
	FROM NexVisionHRM.dbo.WorkFromHomeRequest e WITH (NOLOCK)
	WHERE e.FromDate <= @ToDate AND e.ToDate >= @FromDate AND e.Status <> 3
END