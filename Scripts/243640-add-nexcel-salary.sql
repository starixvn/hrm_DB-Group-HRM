/*
    Created: Henry@20250611
    Task: add salary for nexcel
    DB: bodb_HRM

    Revisions:
        20250611@Henry: add salary for nexcel [Redmine: #243640]
*/

Declare @CompanyId INT = 1

---- Insert SalaryStructure
INSERT INTO [dbo].[SalaryStructure]
   ([CompanyId], [Name], [IsActive], [CreatedDate])
VALUES
   (@CompanyId, N'SD1', 1, GETDATE()),
   (@CompanyId, N'SD2', 1, GETDATE()),
   (@CompanyId, N'SD9 (ITNS)', 1, GETDATE()),
   (@CompanyId, N'Finance', 1, GETDATE()),
   (@CompanyId, N'HR&ADM', 1, GETDATE());


---- Insert EmployeePayroll
DECLARE @SalaryGroupMap TABLE (
   SalaryGroupId INT,
   StructureName NVARCHAR(50)
);
INSERT INTO @SalaryGroupMap (SalaryGroupId, StructureName)
VALUES 
   (1, 'SD1'),
   (2, 'SD2'),
   (3, 'SD9 (ITNS)');

DECLARE @EmpGroupMap TABLE (
   GroupId INT,
   StructureName NVARCHAR(50)
);
INSERT INTO @EmpGroupMap (GroupId, StructureName)
VALUES
   (567, 'HR&ADM'),
   (525, 'Finance');

MERGE [dbo].[EmployeePayroll] AS target
USING (
   SELECT 
       ce.[EmpId],
       s.[SalaryStructureId],
       0 AS [NoOfDependent]
   FROM [dbo].[CompanyEmployee] ce
   OUTER APPLY (
       SELECT TOP 1 gm.StructureName
       FROM @SalaryGroupMap gm
       WHERE gm.SalaryGroupId = ce.SalaryGroupId
   ) AS sg
   OUTER APPLY (
       SELECT TOP 1 egm.StructureName
       FROM @EmpGroupMap egm
       WHERE egm.GroupId = ce.GroupId
   ) AS gg
   INNER JOIN [dbo].[SalaryStructure] s 
       ON s.[CompanyId] = ce.[CompanyId]
      AND s.[Name] = COALESCE(sg.StructureName, gg.StructureName)
   WHERE ce.[CompanyId] = @CompanyId
     AND COALESCE(sg.StructureName, gg.StructureName) IS NOT NULL
) AS src
ON target.[EmpId] = src.[EmpId]
WHEN MATCHED THEN
   UPDATE SET 
       target.[SalaryStructureId] = src.[SalaryStructureId],
       target.[NoOfDependent] = src.[NoOfDependent]
WHEN NOT MATCHED THEN
   INSERT ([EmpId], [SalaryStructureId], [NoOfDependent])
   VALUES (src.[EmpId], src.[SalaryStructureId], src.[NoOfDependent]);

-- Insert SalaryStructureDetail
;WITH LevelBase AS (
    -- Mức lương cơ bản theo từng JobGrade (BS)
    SELECT 'E4-A' AS JobGradeName, 'GMmaDUV4z2OVacnMe+wWMA==' AS BaseSalary   -- 16,750,000
    UNION ALL SELECT 'E4-B', '04UJot5z6/c4MzQ5gZviBQ=='                      -- 15,750,000
    UNION ALL SELECT 'E4-C', 'RP9Dzcchks3N/iCAnMeZ2g=='                      -- 13,500,000

    UNION ALL SELECT 'E3-A', '2qxPYIF8YWYEsNHC8GIJoA=='                      -- 12,250,000
    UNION ALL SELECT 'E3-B', 'JdKdQu4N1FJviVCcr4en0g=='                      -- 11,500,000
    UNION ALL SELECT 'E3-C', '76512xhrSaXKP1HBBlQw9A=='                      -- 10,750,000

    UNION ALL SELECT 'E2-A', 'GvGXbNwQtoc='                                  -- 9,750,000
    UNION ALL SELECT 'E2-B', 'dOAb5kUq0Og='                                  -- 9,000,000
    UNION ALL SELECT 'E2-C', '8+OnnoDdgm0='                                  -- 8,250,000

    UNION ALL SELECT 'E1-A', '3BOF5KAuUYw='                                  -- 7,500,000
    UNION ALL SELECT 'E1-B', 'HjDusaQO9mQ='                                  -- 6,500,000
    UNION ALL SELECT 'E1-C', 'b9EfqZa6KC0='                                  -- 5,500,000

    UNION ALL SELECT 'E0-A', 'H/dCxg9pJy0='                                  -- 4,750,000
    -- E0-B, E0-C không có BS trong bảng gốc của bạn -> để NULL
    UNION ALL SELECT 'E0-B', NULL
    UNION ALL SELECT 'E0-C', NULL
),
SalaryMatrix AS (
    ---------------------------------------------------
    -- E4-A
    ---------------------------------------------------
    SELECT 'E4-A' AS JobGradeName, 'SD1' AS SalaryStructureName, 'pJDWUjJhokmQdx8twUgGYw==' AS JobLevelAddOn   -- 71,000,000
    UNION ALL SELECT 'E4-A', 'SD2',        'qRfpoS5H4Nik49yqgrgk7g=='                                         -- 48,750,000
    UNION ALL SELECT 'E4-A', 'SD9 (ITNS)', 'FrKduhuHDZA='                                                     -- 6,775,000
    UNION ALL SELECT 'E4-A', 'Finance',    'MK0HO3wJK0o='                                                     -- 9,375,000
    UNION ALL SELECT 'E4-A', 'HR&ADM',     'ZTMLBmWlvN8='                                                     -- 7,400,000

    ---------------------------------------------------
    -- E4-B
    ---------------------------------------------------
    UNION ALL SELECT 'E4-B', 'SD1',        'hP/LevTfoLKROkOrsuLqQw=='                                         -- 63,000,000
    UNION ALL SELECT 'E4-B', 'SD2',        'VUwmS/O50waNTtQFxx0x2g=='                                         -- 43,250,000
    UNION ALL SELECT 'E4-B', 'SD9 (ITNS)', 'yUTONSfS8VM='                                                     -- 6,450,000
    UNION ALL SELECT 'E4-B', 'Finance',    'COQlHHsbOOE='                                                     -- 9,075,000
    UNION ALL SELECT 'E4-B', 'HR&ADM',     'glvMQEWhOTw='                                                     -- 7,125,000

    ---------------------------------------------------
    -- E4-C
    ---------------------------------------------------
    UNION ALL SELECT 'E4-C', 'SD1',        'WDL4mCvnhO3tDIPQSCLJjw=='                                         -- 57,000,000
    UNION ALL SELECT 'E4-C', 'SD2',        'AF8Vjo9e1PtEREuaQQOzxw=='                                         -- 39,500,000
    UNION ALL SELECT 'E4-C', 'SD9 (ITNS)', 'rQ1I9Z4OFwc='                                                     -- 5,525,000
    UNION ALL SELECT 'E4-C', 'Finance',    'wf5aJiJ/QvU='                                                     -- 7,850,000
    UNION ALL SELECT 'E4-C', 'HR&ADM',     'cyJ66aIIXrE='                                                     -- 6,300,000

    ---------------------------------------------------
    -- E3-A
    ---------------------------------------------------
    UNION ALL SELECT 'E3-A', 'SD1',        '83RlS3lMpovBqV+Yp/7rsA=='                                         -- 50,250,000
    UNION ALL SELECT 'E3-A', 'SD2',        'UIJf6e4OOyg0FCfMGCM/qw=='                                         -- 35,250,000
    UNION ALL SELECT 'E3-A', 'SD9 (ITNS)', '8i0WGPYsbsY='                                                     -- 5,425,000
    UNION ALL SELECT 'E3-A', 'Finance',    '01Fh3t0BrH8='                                                     -- 6,900,000
    UNION ALL SELECT 'E3-A', 'HR&ADM',     'VRbWV0qIHy8='                                                     -- 6,000,000

    ---------------------------------------------------
    -- E3-B
    ---------------------------------------------------
    UNION ALL SELECT 'E3-B', 'SD1',        'JT6o09ZlWNDI2pQW/aGdEw=='                                         -- 44,250,000
    UNION ALL SELECT 'E3-B', 'SD2',        'wWOirFPfL6v6M/pzEtoMFQ=='                                         -- 31,250,000
    UNION ALL SELECT 'E3-B', 'SD9 (ITNS)', 'goXCnNZcOOQ='                                                     -- 5,250,000
    UNION ALL SELECT 'E3-B', 'Finance',    'b7cgx+zDwmM='                                                     -- 6,400,000
    UNION ALL SELECT 'E3-B', 'HR&ADM',     'Evj0eTeTjAk='                                                     -- 5,775,000

    ---------------------------------------------------
    -- E3-C
    ---------------------------------------------------
    UNION ALL SELECT 'E3-C', 'SD1',        '7lIe1SITUz3J9rnUxvVWDg=='                                         -- 38,500,000
    UNION ALL SELECT 'E3-C', 'SD2',        '41d7oB8iJ+N7qzq6XAEmLw=='                                         -- 27,000,000
    UNION ALL SELECT 'E3-C', 'SD9 (ITNS)', 'naa7XHRijhk='                                                     -- 5,000,000
    UNION ALL SELECT 'E3-C', 'Finance',    'UUuj23YX6Vw='                                                     -- 5,950,000
    UNION ALL SELECT 'E3-C', 'HR&ADM',     '8i0WGPYsbsY='                                                     -- 5,425,000

    ---------------------------------------------------
    -- E2-A
    ---------------------------------------------------
    UNION ALL SELECT 'E2-A', 'SD1',        'LJFIe3lzwmHWNPD6+ciDgA=='                                         -- 33,000,000
    UNION ALL SELECT 'E2-A', 'SD2',        'ITq9lXLrbACNhozQtWzhuw=='                                         -- 23,250,000
    UNION ALL SELECT 'E2-A', 'SD9 (ITNS)', 'H/dCxg9pJy0='                                                     -- 4,750,000
    UNION ALL SELECT 'E2-A', 'Finance',    'afYdC44huf0='                                                     -- 5,025,000
    UNION ALL SELECT 'E2-A', 'HR&ADM',     'afYdC44huf0='                                                     -- 5,025,000

    ---------------------------------------------------
    -- E2-B
    ---------------------------------------------------
    UNION ALL SELECT 'E2-B', 'SD1',        'xdwTLNdxpVBZ3CWuab1SCw=='                                         -- 28,250,000
    UNION ALL SELECT 'E2-B', 'SD2',        'LHRPyUmEnEN5fAvH3rvBpQ=='                                         -- 19,750,000
    UNION ALL SELECT 'E2-B', 'SD9 (ITNS)', '60EtCtOsKt4='                                                     -- 4,475,000
    UNION ALL SELECT 'E2-B', 'Finance',    '6ScaVjUEwcc='                                                     -- 4,650,000
    UNION ALL SELECT 'E2-B', 'HR&ADM',     '6ScaVjUEwcc='                                                     -- 4,650,000

    ---------------------------------------------------
    -- E2-C
    ---------------------------------------------------
    UNION ALL SELECT 'E2-C', 'SD1',        'gk5e8/PBQ8DrlqrPWzdfnQ=='                                         -- 24,000,000
    UNION ALL SELECT 'E2-C', 'SD2',        'yro75YTzEL2c3sssU0metg=='                                         -- 17,000,000
    UNION ALL SELECT 'E2-C', 'SD9 (ITNS)', 'mZFlAuP3uXw='                                                     -- 4,225,000
    UNION ALL SELECT 'E2-C', 'Finance',    'D5zzy9nUI9g='                                                     -- 4,400,000
    UNION ALL SELECT 'E2-C', 'HR&ADM',     'D5zzy9nUI9g='                                                     -- 4,400,000

    ---------------------------------------------------
    -- E1-A
    ---------------------------------------------------
    UNION ALL SELECT 'E1-A', 'SD1',        'BTAadJIYRcmccMF0eE3Zkw=='                                         -- 20,750,000
    UNION ALL SELECT 'E1-A', 'SD2',        '7iUaZXEG3d4qD/DYhANtdA=='                                         -- 14,250,000
    UNION ALL SELECT 'E1-A', 'SD9 (ITNS)', '+Ti1O5XopwI='                                                     -- 3,575,000
    UNION ALL SELECT 'E1-A', 'Finance',    '+Ti1O5XopwI='                                                     -- 3,575,000
    UNION ALL SELECT 'E1-A', 'HR&ADM',     '+Ti1O5XopwI='                                                     -- 3,575,000

    ---------------------------------------------------
    -- E1-B
    ---------------------------------------------------
    UNION ALL SELECT 'E1-B', 'SD1',        'db9LHeqFSv6Rdu7xSBwuqw=='                                         -- 18,250,000
    UNION ALL SELECT 'E1-B', 'SD2',        '2qxPYIF8YWYEsNHC8GIJoA=='                                         -- 12,250,000
    UNION ALL SELECT 'E1-B', 'SD9 (ITNS)', 'O4XWfOuyvYo='                                                     -- 3,550,000
    UNION ALL SELECT 'E1-B', 'Finance',    'O4XWfOuyvYo='                                                     -- 3,550,000
    UNION ALL SELECT 'E1-B', 'HR&ADM',     'O4XWfOuyvYo='                                                     -- 3,550,000

    ---------------------------------------------------
    -- E1-C
    ---------------------------------------------------
    UNION ALL SELECT 'E1-C', 'SD1',        'Gg+Ixo8BUsuilauO4myneQ=='                                         -- 16,000,000
    UNION ALL SELECT 'E1-C', 'SD2',        '76512xhrSaXKP1HBBlQw9A=='                                         -- 10,750,000
    UNION ALL SELECT 'E1-C', 'SD9 (ITNS)', 'ReOfPNlnY0g='                                                     -- 3,500,000
    UNION ALL SELECT 'E1-C', 'Finance',    'ReOfPNlnY0g='                                                     -- 3,500,000
    UNION ALL SELECT 'E1-C', 'HR&ADM',     'ReOfPNlnY0g='                                                     -- 3,500,000

    ---------------------------------------------------
    -- E0-A
    ---------------------------------------------------
    UNION ALL SELECT 'E0-A', 'SD1',        'RIdxDh08IW3dwHyCxcLRWA=='                                         -- 12,500,000
    UNION ALL SELECT 'E0-A', 'SD2',        'REDBJ21lbe1ghgF1wMPLSw=='                                         -- 10,000,000
    UNION ALL SELECT 'E0-A', 'SD9 (ITNS)', 'xmIUjUe7oYg='                                                     -- 3,150,000
    UNION ALL SELECT 'E0-A', 'Finance',    'xmIUjUe7oYg='                                                     -- 3,150,000
    UNION ALL SELECT 'E0-A', 'HR&ADM',     'xmIUjUe7oYg='                                                     -- 3,150,000

    ---------------------------------------------------
    -- E0-B (chỉ có SD1, SD2)
    ---------------------------------------------------
    UNION ALL SELECT 'E0-B', 'SD1',        'RIdxDh08IW3dwHyCxcLRWA=='                                         -- 12,500,000
    UNION ALL SELECT 'E0-B', 'SD2',        'REDBJ21lbe1ghgF1wMPLSw=='                                         -- 10,000,000

    ---------------------------------------------------
    -- E0-C (chỉ có SD1, SD2)
    ---------------------------------------------------
    UNION ALL SELECT 'E0-C', 'SD1',        'RIdxDh08IW3dwHyCxcLRWA=='                                         -- 12,500,000
    UNION ALL SELECT 'E0-C', 'SD2',        'REDBJ21lbe1ghgF1wMPLSw=='                                         -- 10,000,000
)
INSERT INTO [dbo].[SalaryStructureDetail]
    ([SalaryStructureId], [JobLevelId], [BasicSalary], [ExpatSalary], [JobLevelAddOn])
SELECT
    ss.SalaryStructureId,
    jg.JobGradeId,
    lb.BaseSalary,              -- luôn là BS theo level
    NULL AS ExpatSalary,
    sm.JobLevelAddOn            -- số tiền theo SD1/SD2/... đưa vào JobLevelAddOn
FROM SalaryMatrix sm
INNER JOIN LevelBase lb
    ON sm.JobGradeName = lb.JobGradeName
INNER JOIN [dbo].[SalaryStructure] ss
    ON ss.[Name] = sm.SalaryStructureName
   AND ss.[CompanyId] = @CompanyId
INNER JOIN [HRM].[dbo].[JobGrade] jg
    ON jg.[Name] = sm.JobGradeName;