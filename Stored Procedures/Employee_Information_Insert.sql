/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Employee_Information_Insert]
(
    @CompanyId SMALLINT
    ,@UserId INT
    ,@FullName NVARCHAR(50)
    ,@Nickname NVARCHAR(20)
    ,@Code VARCHAR(20)
    ,@TeamId INT
    ,@Password NVARCHAR(100)
    ,@CreatedDate DATETIME
    ,@JoinDate DATETIME
    ,@createBy INT
    ,@EmpId INT OUTPUT
    ,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: 20250306@Tim
    Task: create employee
    DB: bodb_HRM

    Revisions:
        20250306@Tim: initial - [Redmine: #217976]
		20250815@Mira: Auto generate CtrId - [Redmine: #236138]
        20250819@Tim: restructure [Redmine: #235678]
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @MemberRole NVARCHAR(10) = 1
        ,@OldEmpId INT
		,@MaxCtrId INT
        ,@NewEmpId INT

    SELECT @OldEmpId = MAX(ce.OldEmpId)
    FROM dbo.CompanyEmployee AS ce WITH (NOLOCK)
    WHERE ce.CompanyId = @CompanyId

    SET @OldEmpId = ISNULL(@OldEmpId, 0) + 1

	SELECT @MaxCtrId = MAX(CtrId)
    FROM dbo.Employee WITH (NOLOCK)

    SET @MaxCtrId = ISNULL(@MaxCtrId, 0) + 1

    SELECT @NewEmpId = MAX(EmpId)
    FROM dbo.CompanyEmployee WITH (NOLOCK)

    SET @NewEmpId = ISNULL(@NewEmpId, 0) + 1
    SET @EmpId = @NewEmpId

    INSERT INTO dbo.Employee (UserId, FullName, JoinedDate, [Password], CtrId)
    VALUES (@UserId, @FullName, @JoinDate, @Password, @MaxCtrId)

	INSERT INTO dbo.CompanyEmployee (
        EmpId
        ,CompanyId
		,UserId
        ,Code
		,Nickname
		,isDeleted
		,[Enabled]
		,GroupId
		,CreatedDate
		,CreatedBy
        ,OldEmpId
		)
	VALUES (
		@NewEmpId
        ,@CompanyId
        ,@UserId
        ,@Code
		,@Nickname
		,0
		,1
		,@TeamId
		,@CreatedDate
		,@createBy
        ,@OldEmpId
		)

	INSERT INTO dbo.EmployeeSummary (EmpId, IsDefaultSchedule)
	VALUES (@NewEmpId, 0)

	INSERT INTO dbo.EmployeeContract (EmpId)
	VALUES (@NewEmpId)

	INSERT INTO dbo.EmployeeDefaultShift (EmpId)
	VALUES (@NewEmpId)

	EXEC dbo.EmployeeRole_Insert @EmployeeId = @NewEmpId
		,@RoleIds = @MemberRole
		,@ModifiedBy = @createBy
END