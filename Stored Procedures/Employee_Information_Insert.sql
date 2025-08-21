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
	SET @MaxCtrId = (SELECT MAX(CtrId) FROM Employee);

    SELECT @NewEmpId = MAX(EmpId)
    FROM dbo.CompanyEmployee WITH (NOLOCK)

    SET @NewEmpId = ISNULL(@NewEmpId, 0) + 1

    INSERT INTO dbo.Employee (UserId, FullName, JoinedDate, [Password], CtrId)
    VALUES (@UserId, @FullName, @JoinDate, @Password, @MaxCtrId + 1)

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