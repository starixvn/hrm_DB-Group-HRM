/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_GetMemberByGender] @Gender INT
	,@Query NVARCHAR(100)
	,@CompanyId SMALLINT
AS
/*
Created: 20190506@Oliver.Dang
Task: Get member by gender.
DB: SMSHRM
Original: 

Revisions:  
Param's Explanation:
Gender == 0 ? Female : Male
*/
BEGIN
	SET NOCOUNT ON;

	IF (ISNULL(@Query, '') <> '')
		SET @Query = '%' + @Query + '%'

	SELECT DISTINCT emp.EmpId As Id
		,emp.NickName
		,emp.FullName
	FROM dbo.Employee AS emp WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON emp.EmpId = c.EmpId
	WHERE (emp.NickName LIKE '%' + @query + '%'
		OR emp.FullName LIKE '%' + @query + '%')
		AND emp.isDeleted = 0
		AND emp.[Enabled] = 1
		AND emp.Gender = @Gender
		AND c.CompanyId = @CompanyId
END



