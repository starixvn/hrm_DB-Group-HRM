 
USE bodb_HRM
GO
DECLARE @EmployeeMapping TABLE (
    EmpId INT,
	NickName VARCHAR(255)	
 );


 INSERT INTO @EmployeeMapping (EmpId, NickName) 
 VALUES
  (260, 'Rose.Tang'),
 (261, 'Yvon'),
 (270, 'Laura'),
 (287, 'Binh.Hua'),
 (293, 'Chi'),
 (473, 'Ying'),
 (538, 'Ha.Ly'),
 (780, 'Tina.Chen'),
 (821, 'Ellist'),
 (846, 'Helen.Tu'),
 (860, 'Grace.Tong'),
 (921, 'May.Ton'),
 (942, 'Miki.Mac'),
 (1043, 'Yanlee'),
 (1048, 'Tullia'),
 (1060, 'Stella.Nguyen'),
 (1076, 'Tiny'),
 (1180, 'Selina'),
 (1194, 'Iky'),
 (3800, 'Cindy'),
 (3851, 'Kate'),
 (3908, 'Grainne'),
 (3911, 'Winifred')

UPDATE  e
SET e.GroupId = 13,
	e.ModifiedDate = GETDATE()
FROM dbo.Employee AS e
INNER JOIN @EmployeeMapping as ce ON ce.EmpId = e.EmpId 
