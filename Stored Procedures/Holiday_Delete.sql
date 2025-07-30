/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Holiday_Delete]
(
    @Id INT
	,@ModifiedBy INT
	,@ModifiedDate DATETIME
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*
    Created: Tom.Vo@2013-10-23
    Task: Delete Holidate by ID
    DB: bodb_HRM

    Revisions:
        20250505@Tim: fix bug delete holiday
    Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @Fromdate DATETIME
	    ,@todate DATETIME
        ,@CompanyId SMALLINT

    SELECT @fromdate = FromDate
	    ,@todate = ToDate
        ,@CompanyId = CompanyId
    FROM dbo.Holiday WITH (NOLOCK)
    WHERE Id = @id

    IF @fromdate < GETDATE()
    BEGIN
	    SELECT @ErrCode = 1
		    ,@ErrMsg = N'Can not delete Holiday in the past.'
    END
    ELSE
    BEGIN
	    UPDATE ec
	    SET ec.IsHoliday = 0
		    ,ec.ModifiedBy = @ModifiedBy
		    ,ec.ModifiedDate = @ModifiedDate
        FROM dbo.EmployeeCalendar AS ec WITH (ROWLOCK)
            INNER JOIN dbo.CompanyEmployee AS ce WITH (NOLOCK) ON ec.EmpId = ce.EmpId
	    WHERE ce.CompanyId = @CompanyId
            AND ec.WorkDate BETWEEN @FromDate AND @ToDate

	    DELETE
	    FROM dbo.Holiday WITH (ROWLOCK)
	    WHERE Id = @id
    END
END