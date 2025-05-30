USE [FBM]
GO
    ---------------Update EmpId For SMS----------
ALTER TABLE Employee 
ADD IsSecondment BIT NULL;

DELETE
FROM EmpCalendar
WHERE CompanyID = 2 AND EmpId NOT IN (SELECT EmpId FROM Employee WHERE CompanyId = 2)
GO 


UPDATE ec
SET ec.EmpId = e.UserId
FROM EmpCalendar ec
INNER JOIN Employee e ON e.EmpId = ec.EmpId AND e.CompanyId = 2
WHERE ec.CompanyId = 2;

GO 

UPDATE e
SET e.EmpId = e.UserId
FROM Employee e
WHERE e.CompanyID = 2;

GO

    ---------------Update EmpId For HongMa----------
DELETE
FROM EmpCalendar
WHERE CompanyID = 3 AND EmpId NOT IN (SELECT EmpId FROM Employee WHERE CompanyId = 3)
GO 

UPDATE ec
SET ec.EmpId = e.UserId
FROM EmpCalendar ec
INNER JOIN Employee e ON e.EmpId = ec.EmpId AND e.CompanyId = 3
WHERE ec.CompanyId = 3;

GO 

UPDATE e
SET e.EmpId = e.UserId
FROM Employee e
WHERE e.CompanyID = 3;

GO