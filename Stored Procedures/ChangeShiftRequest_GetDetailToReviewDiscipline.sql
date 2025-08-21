/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetDetailToReviewDiscipline] @RequestId BIGINT
AS
/*
Created: 20190930@Tim.Trinh
Task: Get change shift detail to review discipline
DB: HRM

Revisions:
	20250812@Mira: change DB structure [Redmine: #235678]
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	-- change shift type
	DECLARE @ChangeShift TINYINT = 1
		,@MoveOffDay TINYINT = 2

	SELECT csdt.OnDate
		,csdt.FromShift AS FromShiftId
		,s1.Code AS FromShift
		,csdt.ToShift AS ToShiftId
		,s2.Code AS ToShift
		,csdt.Remark
		,csdt.ToDate
	FROM dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
		INNER JOIN dbo.CompanyEmployee AS emp WITH (NOLOCK) ON emp.EmpId = cs.EmpId
		INNER JOIN dbo.EmployeeSummary AS emps WITH (NOLOCK) ON emp.EmpId = emps.EmpId
		INNER JOIN dbo.DisciplineGroupRule AS drule WITH (NOLOCK) ON emp.GroupId = drule.GroupId
		AND drule.DisciplineTypeId = 1
		AND emps.IsLocal = drule.IsLocal
		AND drule.[Value] = 1
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftId = csdt.FromShift
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftId = csdt.ToShift
	WHERE cs.RequestId = @RequestId
		AND cs.TypeId = @ChangeShift
	ORDER BY csdt.OnDate
END