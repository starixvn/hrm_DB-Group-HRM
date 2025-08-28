/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

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
	20250812@Mira: tranfer employee [Redmine: #235678]

Param's Explanation:
Gender == 0 ? Female : Male
*/
BEGIN
	SET NOCOUNT ON;

	IF (ISNULL(@Query, '') <> '')
		SET @Query = '%' + @Query + '%'

	SELECT DISTINCT c.EmpId As Id
		,c.NickName
		,emp.FullName
	FROM dbo.Employee AS emp WITH (NOLOCK)
	INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON emp.UserId = c.UserId
	WHERE (c.NickName LIKE '%' + @query + '%'
		OR emp.FullName LIKE '%' + @query + '%')
		AND c.isDeleted = 0
		AND c.[Enabled] = 1
		AND emp.Gender = @Gender
		AND c.CompanyId = @CompanyId
END



