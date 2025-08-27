/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetByRole] @CompanyId SMALLINT = NULL
    ,@RoleIds VARCHAR(20)
	,@query NVARCHAR(256)
	,@ExcludeIds VARCHAR(2000)
AS
/*
Created: 2013/10/22@Quinn
Task: Get list employee by role (for supervisor list)
DB: HRM
Original:

Revisions:
    - 20250619@Henry: fix ambiguous column error migrate nex
	- 20250730@Jay: Add company name for personal setting page [Redmine: #233324]
	- 20250812@Mira: tranfer employee [Redmine: #235678]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @q NVARCHAR(258)

	SET @q = '%' + @query + '%'

	IF LEN(@query) = 0
		OR @query = ';'
	BEGIN
		SET @query = NULL
	END

	CREATE TABLE #tmpExcludedEmployee (EmpId INT)

	CREATE TABLE #tmpRole (RoleId INT)

	CREATE TABLE #tmpEmployee (EmpId INT)

	INSERT INTO #tmpExcludedEmployee (EmpId)
	SELECT value
	FROM STRING_SPLIT(@ExcludeIds, ',')

	INSERT INTO #tmpRole (RoleId)
	SELECT value
	FROM STRING_SPLIT(@RoleIds, ',')

	INSERT INTO #tmpEmployee
	SELECT ce.EmpId AS Id
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.UserId = e.UserId
        INNER JOIN dbo.EmployeeRole AS r WITH (NOLOCK) ON r.EmployeeId = ce.EmpId
	WHERE 
		(
			@CompanyId IS NULL 
			OR ce.CompanyId = @CompanyId
		)
        AND r.RoleId IN (
			SELECT RoleId
			FROM #tmpRole
			)
		AND ce.EmpId NOT IN (
			SELECT EmpId
			FROM #tmpExcludedEmployee
			)
		AND (
			ce.isDeleted IS NULL
			OR ce.isDeleted = 0
			)
		AND ce.[Enabled] = 1
		AND (
			@query IS NULL
			OR ce.NickName LIKE @q
			OR FullName LIKE @q
			OR ce.DomainUsername LIKE @q
			OR ce.Code LIKE @q
			)

	SELECT ce.EmpId AS Id
		,ce.Code
		,ce.DomainUsername
		,e.FullName
		,ce.NickName
		,e.DOB
		,ce.Email
		,ce.JobTitleId
		,ce.[Enabled]
		,e.Phone
		,e.Gender
		,ce.ManagerId
		,e.JoinedDate
		,e.ConfirmedDate
		,e.ResignedDate
		,e.Skype
		,e.LetsTalk
		,e.Marriage
		,e.LastLogin
		,ce.CreatedDate
		,ce.CreatedBy
		,ce.ModifiedDate
		,ce.ModifiedBy
		,ce.isDeleted
		,e.PermanentAddress AS [Address]
		,e.CurrentAddress
		,e.IdCardNumber AS CardNo
		,e.PassportNo
		,e.PassportExp
		,e.[Password]
		,c.[Name] AS CompanyName
		,c.CompanyId
		,ISNULL(ce.GroupID, - 1) AS [TeamID]
		,ISNULL(g.[Name], '') AS [Team]
	FROM dbo.Employee AS e WITH (NOLOCK)
		LEFT JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ce.UserId = e.UserId
		INNER JOIN #tmpEmployee AS e1 ON e1.EmpId = ce.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON ce.GroupId = g.GroupId
		LEFT JOIN dbo.Company AS c WITH (NOLOCK) ON c.CompanyId = ce.CompanyId

	SELECT emRo.EmployeeId
		,emRo.RoleId
		,loDa.Code
		,loDa.[Name]
	FROM dbo.EmployeeRole AS emRo WITH (NOLOCK)
		INNER JOIN dbo.LookupData AS loDa WITH (NOLOCK) ON emRo.RoleId = loDa.[Value]
		AND 
			(
				@CompanyId IS NULL 
				OR loda.CompanyId = @CompanyId
			)
		INNER JOIN dbo.[Lookup] look WITH (NOLOCK) ON look.Id = loDa.LookupId
		AND look.Code = 'SR' -- System Role
		INNER JOIN #tmpEmployee AS e ON e.EmpId = emRo.EmployeeId

	DROP TABLE #tmpExcludedEmployee

	DROP TABLE #tmpRole

	DROP TABLE #tmpEmployee
END