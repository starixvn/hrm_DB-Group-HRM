/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[UnitDepartmentIds_EmpBelongTo_Get]
(
    @EmpId INT
)
AS
/*
    Created: 20250904@Jay.Do
    Task: get units and departments that user belong to
    DB: bodb_HRM

    Revisions:
		20250904@Jay: update role [Redmine: #237201]

    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	SELECT 
		DISTINCT UnitId AS [Value], 
		'Unit' AS [Key]
	FROM Department
	WHERE PicEmpId = @EmpId 
		OR SupporterEmpId = @EmpId
	UNION
	SELECT 
		DISTINCT UnitId AS [Value], 
		'Unit' AS [Key]
	FROM Unit
	WHERE PicEmpId = @EmpId 
		OR SupporterEmpId = @EmpId
	UNION
	SELECT 
		DISTINCT DepartmentId AS [Value], 
		'Department' AS [Key]
	FROM Department
	WHERE PicEmpId = @EmpId 
		OR SupporterEmpId = @EmpId;
END