/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Report_ManpowerCategory]
(
    @CompanyId SMALLINT
    ,@Year INT
)
AS
/*
    Created: 20151103@Quinn.Vo
    Task: Get data for manpower category report.
    DB: bodb_HRM

    Revisions:
        20250404@Tim: remove section [Redmine: #222886]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FromDate DATETIME
		,@ToDate DATETIME

	SELECT @FromDate = CAST(@Year AS VARCHAR(4)) + '/01/01'
		,@ToDate = CAST(@Year AS VARCHAR(4)) + '/12/31'

	SELECT g.GroupId AS TeamId
		,g.Code AS TeamCode
		,g.[Name] AS TeamName
		,dept.Code AS DepartmentCode
		,dept.[Name] AS DepartmentName
		,SUM(CASE 
				WHEN DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS Total
		,SUM(CASE 
				WHEN es.IsLocal = 0
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS TotalExpat
		,SUM(CASE 
				WHEN es.IsLocal = 1
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS TotalLocal
		,SUM(CASE 
				WHEN job.Value = '5'
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS Management
		,SUM(CASE 
				WHEN job.Value = '4'
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS ExecutiveWithPosition
		,SUM(CASE 
				WHEN job.Value = '3'
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS Executive
		,SUM(CASE 
				WHEN job.Value = '2'
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS Staff
		,SUM(CASE 
				WHEN job.Value = '1'
					AND DATEDIFF(MM, e.JoinedDate, @ToDate) >= 0
					AND (
						e.ResignedDate IS NULL
						OR DATEDIFF(MM, @ToDate, e.ResignedDate) > 0
						) THEN 1
				ELSE 0
				END) AS Worker
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
        INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId
		INNER JOIN dbo.Department AS dept WITH (NOLOCK) ON g.DepartmentId = dept.DepartmentId
		LEFT JOIN dbo.LookupData AS job WITH (NOLOCK) ON e.JobTitleId = job.Id
        AND job.CompanyId = @CompanyId
	WHERE ce.CompanyId = @CompanyId
        AND g.IsDeleted = 0
		AND (e.ResignedDate IS NULL OR YEAR(e.ResignedDate) >= @Year)
	GROUP BY g.GroupId
		,g.Code
		,g.[Name]
		,dept.Code
		,dept.[Name]
END