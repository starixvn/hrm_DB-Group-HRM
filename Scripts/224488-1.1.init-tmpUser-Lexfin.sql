USE [bodb_IUC]
GO

CREATE TABLE [dbo].[tmpInitUser](
	[CtrId] [int] NULL,
	[Code] [varchar](20) NULL,
	[Nickname] [nvarchar](50) NULL,
	[FullName] [nvarchar](100) NULL,
	[TeamCode] [nvarchar](200) NULL,
	[TeamName] [nvarchar](200) NULL,
	[Password] [varchar](100) NULL,
	[IsActive] [bit] NULL,
	[IsDeleted] [bit] NULL,
	[UserId] [int] NULL,
	[RowIndex] [int] IDENTITY(1,1) NOT NULL
) ON [PRIMARY]
GO


DECLARE @Password VARCHAR(100) = '/IirRX6DR+3J+itTfUQPFeDxmyMAAAAAAAAAAA=='; /*123456*/

DECLARE @tmpEmp TABLE (
    [CtrId] INT,
    [TeamName] NVARCHAR(200),
    [TeamCode] NVARCHAR(200),
    [EmpCode] NVARCHAR(200),
    [NickName] NVARCHAR(200),
    [FullName] NVARCHAR(200),
    [RowIndex] INT 
);
-- Insert values
INSERT INTO @tmpEmp ([CtrId], [TeamName], [TeamCode], [EmpCode], [NickName], [FullName], [RowIndex])
VALUES 
  (406, N'Finance', N'FI1', N'LEX0008', N'Rachel', N'Bulahan, Rachel Dizon', 1),
 (784, N'Finance', N'FI1', N'LEX0102', N'Lawrence', N'Tordecillas, Lawrence John Tugnao', 2),
 (998, N'Finance', N'FI1', N'LEX0070', N'Diane', N'Calibuyot, Diane Michelle', 3),
 (293, N'Finance', N'FI1', N'LEX0074', N'Wendy', N'Gamilla, Wendy Almoete', 4),
 (387, N'Finance', N'FI1', N'LEX0034', N'Myleen', N'Espiritu, Myleen Melgar', 5),
 (1362, N'Finance', N'FI1', N'LEX0101', N'Tere', N'Dominguez, Teressa Anihal', 6),
 (517, N'Finance', N'FI1', N'LEX0104', N'Mayann', N'Lajara, Mayann Vergara', 7),
 (1263, N'Finance', N'FI1', N'LEX0078', N'Lea', N'Marcial, Lea Albay', 8),
 (1920, N'Finance', N'FI1', N'LEX0098', N'DJ', N'Sael, Danie Joy', 9),
 (1921, N'Finance', N'FI1', N'LEX0099', N'Joy', N'Barba, Evangielyn Joy Loayon', 10),
 (1487, N'HR', N'HL4', N'LEX0091', N'Cams', N'Aguilan, Ma. Camille Rebutica', 11),
 (811, N'HR', N'HL4', N'LEX0039', N'Erna', N'Lim, Ma. Ernalissa Tinio', 12),
 (814, N'HR', N'HL4', N'LEX0040', N'Loa', N'Perdido, Ma. Luisa Bautista', 13),
 (947, N'HR', N'HL4', N'LEX0062', N'Demz', N'Zamora, Deniezel Pacete', 14),
 (1189, N'HR', N'HL4', N'LEX0077', N'Ruben', N'Tobias, Ruben Anthony III Ongpico', 15),
 (1708, N'HR', N'HL4', N'LEX0092', N'Dhenz', N'Nabre, Dennis Sola', 16),
 (1856, N'HR', N'HL4', N'LEX0095', N'Charlie', N'Quitain, Charlie Reyes', 17),
 (2165, N'HR', N'HL4', N'LEX0103', N'Jayson', N'Capellan, Jayson Abejuela', 18),
 (208, N'Core Team', N'CT1', N'LEX0007', N'David Alfeche', N'Alfeche, David III Santacera', 19),
 (778, N'Lawyer', N'LY2', N'LEX0004', N'Mar', N'Mance, Marilyn Nuval', 20),
 (503, N'Lawyer', N'LY2', N'LEX0001', N'Cel', N'Sison, Maricel Echavez', 21),
 (559, N'Lawyer', N'LY2', N'LEX0009', N'Michael', N'Sebastian, Michael Pagtakhan', 22),
 (884, N'Lawyer', N'LY2', N'LEX0049', N'Jappy', N'Villareal-Guevarra, Jobelle Untalasco', 23),
 (1081, N'Lawyer', N'LY2', N'LEX0075', N'Mari', N'Magrata, Marielle Morales', 24),
 (1469, N'Legal Admin', N'LA2', N'LEX0090', N'Jam', N'Urbina, Jamila Reyes', 25),
 (1890, N'Legal Admin', N'LA2', N'LEX0096', N'Butch', N'Bito, Virgilio Galliguez', 26),
 (1911, N'Legal Admin', N'LA2', N'LEX0097', N'Jasmine', N'Torio, Alyanna Jasmine', 27),
 (2034, N'Legal Admin', N'LA2', N'LEX0100', N'Julie', N'Pascua, Julie Anne Enrera', 28),
 (984, N'Legal Admin', N'LA2', N'LEX0068', N'Bry', N'Sy, Bryan Arabaca', 29),
 (378, N'Legal Admin', N'LA2', N'LEX0016', N'Elaine', N'Bautista, Elaine Corre', 30),
 (488, N'Legal Admin', N'LA2', N'LEX0017', N'Hannah', N'Cruz, Hannah Keeziah Quimpo', 31),
 (520, N'Legal Admin', N'LA2', N'LEX0020', N'Grace', N'Luna, Marie Grace Gonzales', 32),
 (822, N'Legal Admin', N'LA2', N'LEX0043', N'Pat', N'Quilatan, Patrick Laurence, Acosta', 33),
 (682, N'Legal Admin', N'LA2', N'LEX0023', N'Paula', N'Angeles, Paula Kristina Alcaraz', 34),
 (726, N'Legal Admin', N'LA2', N'LEX0025', N'Julie', N'Pascua, Julie Anne Enrera', 35),
 (665, N'Legal Admin', N'LA2', N'LEX0021', N'Nikka', N'Nacis, Nikka Sarah Dela Cruz', 36),
 (670, N'Legal Admin', N'LA2', N'LEX0022', N'Bhob', N'Dagdag, Maricel Domingo', 37),
 (789, N'Legal Admin', N'LA2', N'LEX0036', N'Debbie', N'Muñoz, Denise Abby Bautista', 38),
 (790, N'Legal Admin', N'LA2', N'LEX0037', N'Yana', N'Bautista, Ma. Xheryka Alyana Alcaraz', 39),
 (885, N'Legal Admin', N'LA2', N'LEX0051', N'Ann', N'Tabugara, Mary Ann Santiago', 40),
 (1050, N'Legal Admin', N'LA2', N'LEX0072', N'Tabs', N'Salonga, Tabitha Denise Icban', 41),
 (1407, N'Legal Admin', N'LA2', N'LEX0085', N'Ella', N'Palomo, Elyssa Carmella Pineda', 42),
 (1313, N'Legal Admin', N'LA2', N'LEX0079', N'Raph', N'Tugbo, Raphael Tolentino', 43);


SET IDENTITY_INSERT [dbo].[tmpInitUser] ON 

INSERT INTO dbo.[tmpInitUser](CtrId, Code, FullName, Nickname, TeamCode, TeamName, [Password], IsActive, IsDeleted, RowIndex)
SELECT CtrId, EmpCode, FullName, NickName, TeamCode, TeamName, @Password, 1, 0, RowIndex
FROM @tmpEmp

SET IDENTITY_INSERT [dbo].[tmpInitUser] OFF
GO

