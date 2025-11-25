/*<info serverAlias="HRM-bodb_HRM" executers="wsv_hrm" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[EmployeeWorkFromHome_Update] @EmployeeWorkFromHomeId INT
	,@EmpId INT
	,@FromDate DATE
	,@ToDate DATE = NULL
	,@Remark NVARCHAR(500) = ''
	,@IsCountInHeadcount BIT = 0
	,@ModifiedBy INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20210528@Quinn.Vo
Task: Update Employee Work From Home.
DB: HRM
Original:

Revisions:
	20251120@Lilac: add permanent WFH [Redmine: #244781]

Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM dbo.EmployeeWorkFromHome WITH (NOLOCK)
			WHERE EmployeeWorkFromHomeId <> @EmployeeWorkFromHomeId
				AND EmpId = @EmpId
				AND (
					-- If @ToDate is not NULL, check overlap as before
					(
						@ToDate IS NOT NULL
						AND (
							@FromDate BETWEEN FromDate AND ToDate
							OR @ToDate BETWEEN FromDate AND ToDate
							OR (@FromDate <= FromDate AND @ToDate >= ToDate)
						)
					)
					-- If @ToDate is NULL, check if @FromDate is within existing record's range or new record covers existing one
					OR (
						@ToDate IS NULL
						AND (
							-- @FromDate is within existing record's FromDate - ToDate range
							(
								ToDate IS NOT NULL
								AND @FromDate BETWEEN FromDate AND ToDate
							)
							-- New record (ongoing) covers existing record (existing has ToDate)
							OR (
								ToDate IS NOT NULL
								AND @FromDate <= FromDate
							)
							-- Both records are ongoing (both ToDate are NULL) - any overlap
							OR (
								ToDate IS NULL
							)
						)
					)
				)
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The WFH of this employee is overlapping.'

		RETURN
	END

	IF NOT EXISTS (
			SELECT 1
			FROM dbo.EmployeeWorkFromHome WITH (NOLOCK)
			WHERE EmployeeWorkFromHomeId = @EmployeeWorkFromHomeId
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = N'The WFH of this employee does not exists'

		RETURN
	END

	UPDATE dbo.EmployeeWorkFromHome WITH (ROWLOCK, UPDLOCK)
	SET EmpId = @EmpId
		,FromDate = @FromDate
		,ToDate = @ToDate
		,Remark = @Remark
		,IsCountInHeadcount = @IsCountInHeadcount
		,ModifiedBy = @ModifiedBy
		,ModifiedDate = GETDATE()
	WHERE EmployeeWorkFromHomeId = @EmployeeWorkFromHomeId

END
