
ALTER PROCEDURE [dbo].[API_TimeRecord_Get] @FromDate DATETIME
    ,@ToDate DATETIME
AS
/*
Created: 20250318@Tim
Task: get check in/out
DB: HRM

Revisions:
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SQLString NVARCHAR(4000)
		,@CurrentMonthTableName VARCHAR(50)
		,@LastMonthTableName VARCHAR(50)
		,@fromDateString VARCHAR(10)
		,@toDateString VARCHAR(10)
		,@StartDateConnectBitoStar VARCHAR(10)

	CREATE TABLE #tempFinger (
		nUserID VARCHAR(32)
		,dtDateTime DATETIME
		,nTNAEvent INT
		)

	SELECT @CurrentMonthTableName = 'T_LG' + LEFT(CONVERT(VARCHAR, GETDATE(), 112), 6)
		,@LastMonthTableName = 'T_LG' + LEFT(CONVERT(VARCHAR, DATEADD(MM, - 1, GETDATE()), 112), 6)
		,@fromDateString = CONVERT(VARCHAR, @fromDate, 112)
		,@toDateString = CONVERT(VARCHAR, @toDate, 112)
		,@StartDateConnectBitoStar = '2017-09-15'

	IF EXISTS (
			SELECT 1
			FROM [10.18.114.27].[biostar2_ac].[dbo].[T_LGTBIDX]
			WHERE [LGTABLENM] = @LastMonthTableName
			)
	BEGIN		
		SET @SQLString = N'INSERT INTO #tempFinger(nUserID, dtDateTime, nTNAEvent) 
						SELECT 
						USRID AS nUserID
						  ,DATEADD(HH, 7, DATEADD(s, [DEVDT], ''1970-01-01'')) AS dtDateTime
						  ,[TNAKEY] AS nTNAEvent
					FROM [10.18.114.27].[biostar2_ac].[db_backupoperator].' + @LastMonthTableName + ' WHERE USRID <> '''' AND EVT < 5400
						AND DATEADD(HH, 7, DATEADD(s, [DEVDT], ''1970-01-01'')) > ''' + @fromDateString + '''
						AND DATEADD(HH, 7, DATEADD(s, [DEVDT], ''1970-01-01'')) < DATEADD(d, 1, ''' + @toDateString + ''')
						AND DATEADD(HH, 7, DATEADD(s, [DEVDT], ''1970-01-01'')) > ''' + @StartDateConnectBitoStar + ''''

		EXECUTE sp_executesql @SQLString
	END

	IF EXISTS (
			SELECT 1
			FROM [10.18.114.27].[biostar2_ac].[dbo].[T_LGTBIDX]
			WHERE [LGTABLENM] = @CurrentMonthTableName
			)
	BEGIN
		SET @SQLString = N'INSERT INTO #tempFinger(nUserID, dtDateTime, nTNAEvent) 
						SELECT 
					 USRID AS nUserID
						  ,DATEADD(HH, 7, DATEADD(s, [DEVDT], ''1970-01-01'')) AS dtDateTime
						  ,[TNAKEY] AS nTNAEvent	  
					FROM [10.18.114.27].[biostar2_ac].db_backupoperator.' + @CurrentMonthTableName + ' WHERE USRID <> '''' AND EVT < 5400
						AND DATEADD(HH, 7, DATEADD(s, [DEVDT], ''1970-01-01'')) > ''' + @fromDateString + '''
						AND DATEADD(HH, 7, DATEADD(s, [DEVDT], ''1970-01-01'')) < DATEADD(d, 1, ''' + @toDateString + ''')
						AND DATEADD(HH, 7, DATEADD(s, [DEVDT], ''1970-01-01'')) > ''' + @StartDateConnectBitoStar + ''''

		EXECUTE sp_executesql @SQLString
	END

	SELECT nUserID AS EmpNo
		,dtDateTime AS RecordTime
		,CASE 
			WHEN nTNAEvent = 1 THEN 0
			WHEN nTNAEvent = 2 THEN 1
			ELSE NULL
			END AS InOutType
	FROM #tempFinger WITH (NOLOCK)
	WHERE dtDateTime BETWEEN @FromDate AND @ToDate
	ORDER BY dtDateTime
	
	DROP TABLE #tempFinger
END