/*<info serverAlias="bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_Information_Insert] @CompanyId SMALLINT
    ,@UserId INT
    ,@FullName NVARCHAR(50)
	,@Nickname NVARCHAR(20)
	,@Code VARCHAR(20)
	,@TeamId INT
	,@DomainUsername VARCHAR(50) = ''
	,@Password NVARCHAR(100)
	,@createBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@CreatedDate DATETIME
	,@JoinDate DATETIME
AS
/*
Created: 20250306@Tim
Task: create employee
DB: HRM
Original:

Revisions:
    20250306@Tim: initial - [Redmine: #217976]
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @MemberRole NVARCHAR(10) = 1
        ,@OldEmpId INT

    SELECT @OldEmpId = MAX(e.OldEmpId)
    FROM dbo.Employee AS e WITH (NOLOCK)
        INNER JOIN dbo.CompanyEmployee AS c WITH (NOLOCK) ON e.EmpId = c.EmpId
    WHERE c.CompanyId = @CompanyId

    SET @OldEmpId = ISNULL(@OldEmpId, 0) + 1

	INSERT INTO dbo.Employee (
		EmpId
        ,Code
		,FullName
		,NickName
        ,DomainUsername
		,DOB
		,isDeleted
		,[Enabled]
		,GroupId
        ,JoinedDate
		,[Password]
		,CreatedDate
		,CreatedBy
        ,UserId
        ,OldEmpId
		)
	VALUES (
		@UserId
        ,@code
		,@fullName
		,@Nickname
        ,@DomainUsername
		,NULL
		,0
		,1
		,@TeamId
        ,@JoinDate
		,@password
		,@CreatedDate
		,@createBy
        ,@UserId
        ,@OldEmpId
		)

    INSERT INTO dbo.CompanyEmployee (CompanyId, EmpId)
    VALUES (@CompanyId, @UserId)

	INSERT INTO dbo.EmployeeSummary (
		EmpId
		,IsDefaultSchedule
		)
	VALUES (
		@UserId
		,0
		)

	INSERT INTO dbo.EmployeeContract (EmpId)
	VALUES (@UserId)

	EXEC dbo.EmployeeRole_Insert @EmployeeId = @UserId
		,@RoleIds = @MemberRole
		,@ModifiedBy = @createBy

	INSERT INTO dbo.EmployeeDefaultShift (EmpId)
	VALUES (@UserId)

	INSERT INTO dbo.EmployeeGroup (
		GroupId
		,EmpId
		,isMainGroup
		)
	VALUES (
		@TeamId
		,@UserId
		,1
		)
END