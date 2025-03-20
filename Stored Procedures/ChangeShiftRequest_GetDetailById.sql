/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[ChangeShiftRequest_GetDetailById] @RequestId BIGINT
AS
/*
Created: Tim.Trinh@2019-09-20
Task: get detail by id
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT csdt.OnDate
		,csdt.FromShift AS FromShiftId
		,s1.Code AS FromShift
		,csdt.ToShift AS ToShiftId
		,s2.Code AS ToShift
		,csdt.Remark
		,csdt.ToDate
	FROM dbo.ChangeShiftRequest AS cs WITH (NOLOCK)
		INNER JOIN dbo.ChangeShiftRequestDetail AS csdt WITH (NOLOCK) ON cs.RequestId = csdt.RequestId
		LEFT JOIN dbo.[Shift] AS s1 WITH (NOLOCK) ON s1.ShiftId = csdt.FromShift
		LEFT JOIN dbo.[Shift] AS s2 WITH (NOLOCK) ON s2.ShiftId = csdt.ToShift
	WHERE cs.RequestId = @RequestId
	ORDER BY csdt.OnDate
END