/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetByRole] @CompanyId SMALLINT
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
	SELECT e.EmpId AS Id
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON e.EmpId = ce.EmpId
        INNER JOIN dbo.EmployeeRole AS r WITH (NOLOCK) ON r.EmployeeId = e.EmpId
	WHERE ce.CompanyId = @CompanyId
        AND r.RoleId IN (
			SELECT RoleId
			FROM #tmpRole
			)
		AND e.EmpId NOT IN (
			SELECT EmpId
			FROM #tmpExcludedEmployee
			)
		AND (
			E.isDeleted IS NULL
			OR e.isDeleted = 0
			)
		AND e.[Enabled] = 1
		AND (
			@query IS NULL
			OR NickName LIKE @q
			OR FullName LIKE @q
			OR DomainUsername LIKE @q
			OR e.Code LIKE @q
			)

	SELECT e.EmpId AS Id
		,e.Code
		,e.DomainUsername
		,e.FullName
		,e.NickName
		,e.DOB
		,e.Email
		,e.JobTitleId
		,e.[Enabled]
		,e.Phone
		,e.Gender
		,e.ManagerId
		,e.JoinedDate
		,e.ConfirmedDate
		,e.ResignedDate
		,e.Skype
		,e.LetsTalk
		,e.Marriage
		,e.LastLogin
		,e.CreatedDate
		,e.CreatedBy
		,e.ModifiedDate
		,e.ModifiedBy
		,e.isDeleted
		,e.PermanentAddress AS [Address]
		,e.CurrentAddress
		,e.IdCardNumber AS CardNo
		,e.PassportNo
		,e.PassportExp
		,e.[Password]
		,ISNULL(e.GroupID, - 1) AS [TeamID]
		,ISNULL(g.[Name], '') AS [Team]
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN #tmpEmployee AS e1 ON e1.EmpId = e.EmpId
		INNER JOIN dbo.[Group] AS g WITH (NOLOCK) ON e.GroupId = g.GroupId

	SELECT emRo.EmployeeId
		,emRo.RoleId
		,loDa.Code
		,loDa.[Name]
	FROM dbo.EmployeeRole AS emRo WITH (NOLOCK)
		INNER JOIN dbo.LookupData AS loDa WITH (NOLOCK) ON emRo.RoleId = loDa.[Value]
        AND loda.CompanyId = @CompanyId
		INNER JOIN dbo.[Lookup] look WITH (NOLOCK) ON look.Id = loDa.LookupId
		AND look.Code = 'SR' -- System Role
		INNER JOIN #tmpEmployee AS e ON e.EmpId = emRo.EmployeeId

	DROP TABLE #tmpExcludedEmployee

	DROP TABLE #tmpRole

	DROP TABLE #tmpEmployee
END