/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE FnB_Employee_GetByLastModifiedDate 
	@LastModifiedDate DATETIME
AS
-- Author:		Jay
-- Create date: 14/03/2025
-- Description:	Sync Employee to F&B
BEGIN
	SET NOCOUNT ON;

	IF @LastModifiedDate IS NOT NULL
	BEGIN
		SELECT @LastModifiedDate = DATEADD(HH, - 1, @LastModifiedDate)
	END

	SELECT e.UserId
		,e.EmpId
		,e.[Password]
		,e.Code
		,e.NickName
		,e.FullName
		,e.EmployeeCard
		,e.DomainUsername AS DomainName
		,e.Phone
		,e.Email
		,e.JobTitleId
		,e.[Enabled] AS IsEnabled
		,ISNULL(e.isDeleted, 0) AS IsDeleted
		,e.JoinedDate
		,e.ConfirmedDate
		,es.IsLocal
		,e.GroupId AS TeamId
		,CASE 
			WHEN e.ModifiedDate IS NULL THEN e.CreatedDate
			ELSE e.ModifiedDate
			END AS ModifiedDate
		,es.Unit AS CostCenter
		,e.JobLevelId
	FROM dbo.Employee AS e WITH (NOLOCK)
		INNER JOIN dbo.EmployeeSummary AS es WITH (NOLOCK) ON e.EmpId = es.EmpId
	WHERE @LastModifiedDate IS NULL
		OR e.ModifiedDate > @LastModifiedDate
		OR e.CreatedDate > @LastModifiedDate
	ORDER BY e.ModifiedDate
END
GO
