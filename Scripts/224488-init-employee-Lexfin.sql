USE [bodb_HRM]
GO

ALTER TABLE [dbo].[Employee]  
ALTER COLUMN OldEmpId INT NULL;
GO


-- INSERT NEW TEAM
DECLARE @tmpEmp TABLE (
    [CtrId] INT,
    [TeamName] NVARCHAR(200),
    [TeamCode] NVARCHAR(200),
    [EmpCode] NVARCHAR(200),
    [EmpName] NVARCHAR(200)
);

-- Insert values
INSERT INTO @tmpEmp ([CtrId], [TeamName], [TeamCode], [EmpCode], [EmpName])
VALUES 
 (406, 'Finance', 'FI1', '0008', 'Rachel'),
 (784, 'Finance', 'FI1', '0102', 'Lawrence'),
 (998, 'Finance', 'FI1', '0070', 'Diane'),
 (293, 'Finance', 'FI1', '0074', 'Wendy'),
 (387, 'Finance', 'FI1', '0034', 'Myleen'),
 (1362, 'Finance', 'FI1', '0101', 'Tere'),
 (517, 'Finance', 'FI1', '0104', 'Mayann'),
 (1263, 'Finance', 'FI1', '0078', 'Lea'),
 (1920, 'Finance', 'FI1', '0098', 'DJ'),
 (1921, 'Finance', 'FI1', '0099', 'Joy'),
 (1487, 'HR', 'HL4', '0091', 'Cams'),
 (811, 'HR', 'HL4', '0039', 'Erna'),
 (814, 'HR', 'HL4', '0040', 'Loa'),
 (947, 'HR', 'HL4', '0062', 'Demz'),
 (1189, 'HR', 'HL4', '0077', 'Ruben'),
 (1708, 'HR', 'HL4', '0092', 'Dhenz'),
 (1856, 'HR', 'HL4', '0095', 'Charlie'),
 (2165, 'HR', 'HL4', '0103', 'Jayson'),
 (208, 'Core Team', 'CT1', '0007', 'David Alfeche'),
 (778, 'Lawyer', 'LY2', '0004', 'Mar'),
 (503, 'Lawyer', 'LY2', '0001', 'Cel'),
 (559, 'Lawyer', 'LY2', '0009', 'Michael'),
 (884, 'Lawyer', 'LY2', '0049', 'Jappy'),
 (1081, 'Lawyer', 'LY2', '0075', 'Mari'),
 (1469, 'Legal Admin', 'LA2', '0090', 'Jam'),
 (1890, 'Legal Admin', 'LA2', '0096', 'Butch'),
 (1911, 'Legal Admin', 'LA2', '0097', 'Jasmine'),
 (2034, 'Legal Admin', 'LA2', '0100', 'Julie'),
 (984, 'Legal Admin', 'LA2', '0068', 'Bry'),
 (378, 'Legal Admin', 'LA2', '0016', 'Elaine'),
 (488, 'Legal Admin', 'LA2', '0017', 'Hannah'),
 (520, 'Legal Admin', 'LA2', '0020', 'Grace'),
 (822, 'Legal Admin', 'LA2', '0043', 'Pat'),
 (682, 'Legal Admin', 'LA2', '0023', 'Paula'),
 (726, 'Legal Admin', 'LA2', '0025', 'Julie'),
 (665, 'Legal Admin', 'LA2', '0021', 'Nikka'),
 (670, 'Legal Admin', 'LA2', '0022', 'Bhob'),
 (789, 'Legal Admin', 'LA2', '0036', 'Debbie'),
 (790, 'Legal Admin', 'LA2', '0037', 'Yana'),
 (885, 'Legal Admin', 'LA2', '0051', 'Ann'),
 (1050, 'Legal Admin', 'LA2', '0072', 'Tabs'),
 (1407, 'Legal Admin', 'LA2', '0085', 'Ella'),
 (1313, 'Legal Admin', 'LA2', '0079', 'Raph');


INSERT INTO [dbo].[Employee]
           ([Code]
           ,[FullName]
           ,[NickName]
           ,[Enabled]
           ,[GroupId]
           ,[CreatedDate]
           ,[isDeleted]
           ,[CtrId])
SELECT e.EmpCode
      ,e.EmpName
      ,e.EmpName
      ,1
      ,g.GroupId
      ,GETDATE()
      ,0
      ,e.CtrId
FROM @tmpEmp e
LEFT JOIN [dbo].[Group] g WITH(NOLOCK) ON g.Code = e.TeamCode

GO

