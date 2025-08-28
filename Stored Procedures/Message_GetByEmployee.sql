/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Message_GetByEmployee] @EmployeeId INT
	,@FromDate DATETIME
	,@ToDate DATETIME
	,@IsDisabled BIT = NULL
AS
/*
Created: 20140714@Quinn.Vo
Task: Get message by employee.
DB: HRM

Revisions:
	20250812@Mira: tranfer employee [Redmine: #235678]

*/
BEGIN
	SET NOCOUNT ON;

	SELECT ms.MessageId
		,ms.[Subject]
		,ms.[Contents]
		,ms.[Category]
		,ms.[FromDate]
		,ms.[ToDate]
		,ISNULL(mse.IsRead, 0) AS IsRead
		,ISNULL(mse.IsDisabled, 1)
	FROM dbo.[Message] AS ms WITH (NOLOCK)
		INNER JOIN dbo.MessageGroup AS mg WITH (NOLOCK) ON ms.MessageId = mg.MessageId
		INNER JOIN dbo.CompanyEmployee AS e WITH (NOLOCK) ON mg.GroupId = e.GroupId
		LEFT JOIN dbo.MessageEmployee AS mse WITH (NOLOCK) ON e.EmpId = mse.EmployeeId
		AND ms.MessageId = mse.MessageId
	WHERE e.EmpId = @EmployeeId
		AND (
			@IsDisabled IS NULL
			OR ms.IsDisabled = @IsDisabled
			)
		AND (
			@IsDisabled IS NULL
			OR mse.IsDisabled IS NULL
			OR mse.IsDisabled = @IsDisabled
			)
		AND (
			ms.FromDate IS NULL
			OR ms.ToDate IS NULL
			--OR ISNULL(mse.IsRead, 0) = 0
			OR @FromDate BETWEEN ms.FromDate
				AND ms.ToDate
			OR ms.FromDate BETWEEN @FromDate
				AND @ToDate
			)
	
	UNION
	SELECT m.MessageId
		,m.[Subject]
		,m.[Contents]
		,m.[Category]
		,m.[FromDate]
		,m.[ToDate]
		,ISNULL(me.IsRead, 0) AS IsRead
		,me.IsDisabled
	FROM dbo.[Message] AS m WITH (NOLOCK)
		INNER JOIN dbo.MessageEmployee AS me WITH (NOLOCK) ON m.MessageId = me.MessageId
	WHERE me.EmployeeId = @EmployeeId
		AND (
			@IsDisabled IS NULL
			OR me.IsDisabled = @IsDisabled
			)
		AND (
			m.FromDate IS NULL
			OR m.ToDate IS NULL
			--OR me.IsRead = 0
			OR @FromDate BETWEEN m.FromDate
				AND m.ToDate
			OR m.FromDate BETWEEN @FromDate
				AND @ToDate
			)
END