use bodb_HRM
go

exec [dbo].[tmpEmployeeCalendar_Insert]
    @CompanyId = 3
    ,@fromDate = '2025-06-05'
	,@toDate = '2025-06-23'
	,@empIds = '56,170,440,443,732,3807,3844,434,436,5977,5980,5986,5981,5985,6003,5993,5976,5987,5983'
	,@isEnable = NULL
	,@isDelete = NULL
	,@isUpdateRequestData = 1