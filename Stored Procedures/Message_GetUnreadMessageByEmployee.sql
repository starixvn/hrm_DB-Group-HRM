/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Message_GetUnreadMessageByEmployee] @EmployeeId INT
AS
/*
Created: 20140729@Quinn.Vo
Task: Get unread message by employee.
DB: HRM

Revisions:  
        20250812@Mira: tranfer employee [Redmine: #235678]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ms.MessageId,
		ms.[Subject],
		ms.[Contents],
		ms.[Category],
		ms.[FromDate],
		ms.[ToDate],
		ISNULL(mse.IsRead, 0) AS IsRead
	FROM dbo.[Message] AS ms WITH (NOLOCK)
	    INNER JOIN dbo.MessageGroup AS mg WITH (NOLOCK) ON ms.MessageId = mg.MessageId
	    INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON mg.GroupId = ce.GroupId
	    LEFT JOIN dbo.MessageEmployee AS mse WITH (NOLOCK) ON ce.EmpId = mse.EmployeeId AND ms.MessageId = mse.MessageId
        AND mse.IsDisabled = 0
	WHERE ce.EmpId = @EmployeeId 
		AND mse.EmployeeId IS NULL
        AND ms.IsDisabled = 0

	UNION
	SELECT m.MessageId,
		m.[Subject],
		m.[Contents],
		m.[Category],
		m.[FromDate],
		m.[ToDate],
		ISNULL(me.IsRead, 0) AS IsRead
	FROM dbo.[Message] AS m WITH (NOLOCK)
	    INNER JOIN dbo.MessageEmployee AS me WITH (NOLOCK) ON m.MessageId = me.MessageId
	WHERE me.EmployeeId = @EmployeeId 
		AND me.IsDisabled = 0
		AND me.IsRead = 0
        AND m.IsDisabled = 0
END