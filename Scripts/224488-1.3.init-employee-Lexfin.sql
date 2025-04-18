USE [bodb_HRM]
GO

ALTER TABLE [dbo].[Employee]  
ALTER COLUMN OldEmpId INT NULL;
GO


-- INSERT NEW TEAM
DECLARE @tmpEmployeeInfo TABLE (
    [CtrId] INT,
    [TeamName] NVARCHAR(200),
    [TeamCode] NVARCHAR(200),
    [EmpCode] NVARCHAR(200),
    [NickName] NVARCHAR(200),
    [FullName] NVARCHAR(200),
    [UserId] INT,
    [RowIndex] INT 
);

-- Insert values
INSERT INTO @tmpEmployeeInfo ([CtrId], [EmpCode], [NickName], [FullName], [TeamCode], [TeamName], [UserId], [RowIndex])
VALUES 
  (406, N'LEX0008', N'Rachel', N'Bulahan, Rachel Dizon', N'FI1', N'Finance',7434, 1),
 (784, N'LEX0102', N'Lawrence', N'Tordecillas, Lawrence John Tugnao', N'FI1', N'Finance',7435, 2),
 (998, N'LEX0070', N'Diane', N'Calibuyot, Diane Michelle', N'FI1', N'Finance',7436, 3),
 (293, N'LEX0074', N'Wendy', N'Gamilla, Wendy Almoete', N'FI1', N'Finance',7437, 4),
 (387, N'LEX0034', N'Myleen', N'Espiritu, Myleen Melgar', N'FI1', N'Finance',7438, 5),
 (1362, N'LEX0101', N'Tere', N'Dominguez, Teressa Anihal', N'FI1', N'Finance',7439, 6),
 (517, N'LEX0104', N'Mayann', N'Lajara, Mayann Vergara', N'FI1', N'Finance',7440, 7),
 (1263, N'LEX0078', N'Lea', N'Marcial, Lea Albay', N'FI1', N'Finance',7441, 8),
 (1920, N'LEX0098', N'DJ', N'Sael, Danie Joy', N'FI1', N'Finance',7442, 9),
 (1921, N'LEX0099', N'Joy', N'Barba, Evangielyn Joy Loayon', N'FI1', N'Finance',7443, 10),
 (1487, N'LEX0091', N'Cams', N'Aguilan, Ma. Camille Rebutica', N'HL4', N'HR',7444, 11),
 (811, N'LEX0039', N'Erna', N'Lim, Ma. Ernalissa Tinio', N'HL4', N'HR',7445, 12),
 (814, N'LEX0040', N'Loa', N'Perdido, Ma. Luisa Bautista', N'HL4', N'HR',7446, 13),
 (947, N'LEX0062', N'Demz', N'Zamora, Deniezel Pacete', N'HL4', N'HR',7447, 14),
 (1189, N'LEX0077', N'Ruben', N'Tobias, Ruben Anthony III Ongpico', N'HL4', N'HR',7448, 15),
 (1708, N'LEX0092', N'Dhenz', N'Nabre, Dennis Sola', N'HL4', N'HR',7449, 16),
 (1856, N'LEX0095', N'Charlie', N'Quitain, Charlie Reyes', N'HL4', N'HR',7450, 17),
 (2165, N'LEX0103', N'Jayson', N'Capellan, Jayson Abejuela', N'HL4', N'HR',7451, 18),
 (208, N'LEX0007', N'David Alfeche', N'Alfeche, David III Santacera', N'CT1', N'Core Team',7452, 19),
 (778, N'LEX0004', N'Mar', N'Mance, Marilyn Nuval', N'LY2', N'Lawyer',7453, 20),
 (503, N'LEX0001', N'Cel', N'Sison, Maricel Echavez', N'LY2', N'Lawyer',7454, 21),
 (559, N'LEX0009', N'Michael', N'Sebastian, Michael Pagtakhan', N'LY2', N'Lawyer',7455, 22),
 (884, N'LEX0049', N'Jappy', N'Villareal-Guevarra, Jobelle Untalasco', N'LY2', N'Lawyer',7456, 23),
 (1081, N'LEX0075', N'Mari', N'Magrata, Marielle Morales', N'LY2', N'Lawyer',7457, 24),
 (1469, N'LEX0090', N'Jam', N'Urbina, Jamila Reyes', N'LA2', N'Legal Admin',7458, 25),
 (1890, N'LEX0096', N'Butch', N'Bito, Virgilio Galliguez', N'LA2', N'Legal Admin',7459, 26),
 (1911, N'LEX0097', N'Jasmine', N'Torio, Alyanna Jasmine', N'LA2', N'Legal Admin',7460, 27),
 (2034, N'LEX0100', N'Julie', N'Pascua, Julie Anne Enrera', N'LA2', N'Legal Admin',7461, 28),
 (984, N'LEX0068', N'Bry', N'Sy, Bryan Arabaca', N'LA2', N'Legal Admin',7462, 29),
 (378, N'LEX0016', N'Elaine', N'Bautista, Elaine Corre', N'LA2', N'Legal Admin',7463, 30),
 (488, N'LEX0017', N'Hannah', N'Cruz, Hannah Keeziah Quimpo', N'LA2', N'Legal Admin',7464, 31),
 (520, N'LEX0020', N'Grace', N'Luna, Marie Grace Gonzales', N'LA2', N'Legal Admin',7465, 32),
 (822, N'LEX0043', N'Pat', N'Quilatan, Patrick Laurence, Acosta', N'LA2', N'Legal Admin',7466, 33),
 (682, N'LEX0023', N'Paula', N'Angeles, Paula Kristina Alcaraz', N'LA2', N'Legal Admin',7467, 34),
 (726, N'LEX0025', N'Julie', N'Pascua, Julie Anne Enrera', N'LA2', N'Legal Admin',7468, 35),
 (665, N'LEX0021', N'Nikka', N'Nacis, Nikka Sarah Dela Cruz', N'LA2', N'Legal Admin',7469, 36),
 (670, N'LEX0022', N'Bhob', N'Dagdag, Maricel Domingo', N'LA2', N'Legal Admin',7470, 37),
 (789, N'LEX0036', N'Debbie', N'Muñoz, Denise Abby Bautista', N'LA2', N'Legal Admin',7471, 38),
 (790, N'LEX0037', N'Yana', N'Bautista, Ma. Xheryka Alyana Alcaraz', N'LA2', N'Legal Admin',7472, 39),
 (885, N'LEX0051', N'Ann', N'Tabugara, Mary Ann Santiago', N'LA2', N'Legal Admin',7473, 40),
 (1050, N'LEX0072', N'Tabs', N'Salonga, Tabitha Denise Icban', N'LA2', N'Legal Admin',7474, 41),
 (1407, N'LEX0085', N'Ella', N'Palomo, Elyssa Carmella Pineda', N'LA2', N'Legal Admin',7475, 42),
 (1313, N'LEX0079', N'Raph', N'Tugbo, Raphael Tolentino', N'LA2', N'Legal Admin',7476, 43);

DECLARE @rowIndex INT
	,@TotalRows INT
	,@Password VARCHAR(100) = '/IirRX6DR+3J+itTfUQPFeDxmyMAAAAAAAAAAA=='
    ,@CompanyId INT = 6
SELECT @RowIndex = 1
	,@TotalRows = COUNT(1)
FROM @tmpEmployeeInfo

WHILE @RowIndex <= @TotalRows
BEGIN
    DECLARE @EmpId INT
		,@TeamId INT = NULL
		,@TeamCode NVARCHAR(200)

    SELECT  @TeamCode = TeamCode, @EmpId = UserId
	FROM @tmpEmployeeInfo
	WHERE RowIndex = @rowIndex

	SELECT @TeamId = team.GroupId
	FROM dbo.[Group] AS team WITH (NOLOCK)
	WHERE team.[Code] = @TeamCode and CompanyId = @CompanyId

INSERT INTO [dbo].[Employee]
           ([EmpId]
           ,[Code]
           ,[FullName]
           ,[NickName]
           ,[DOB]
           ,[Enabled]
           ,[GroupId]
           ,[CreatedDate]
           ,[CreatedBy]
           ,[isDeleted]
           ,[Password]
           ,[PasswordReset]
           ,[UserId]
           ,[CtrId])
     SELECT tmp.UserId
           ,tmp.EmpCode
           ,tmp.FullName
           ,tmp.NickName
           ,'1900-01-01'
           ,1
           ,@TeamId
           ,GETDATE()
           ,-1
           ,0
           ,@Password
           ,0
           ,tmp.UserId
           ,tmp.CtrId
     FROM @tmpEmployeeInfo tmp
     WHERE RowIndex = @rowIndex;

     INSERT INTO dbo.CompanyEmployee (EmpId, CompanyId)
     VALUES (@EmpId, @CompanyId);


    INSERT INTO dbo.EmployeeSummary (EmpId, CanOT, WorkingDays, WorkingHours, OffDaysbyWeek, IsLocal, IsTopManager, IsDefaultSchedule)
	SELECT tmp.UserId, 1, 22, 9, 2, 1, 0, 0
	FROM @tmpEmployeeInfo tmp
	WHERE RowIndex = @rowIndex;

    INSERT INTO dbo.EmployeeContract (EmpId)
	VALUES (@EmpId);

    EXEC dbo.EmployeeRole_Insert @EmployeeId = @EmpId
		,@RoleIds = '1'
		,@ModifiedBy = -1;
    
    INSERT INTO dbo.EmployeeDefaultShift (EmpId)
	VALUES (@EmpId);


    SET @RowIndex = @RowIndex + 1;
END

GO






