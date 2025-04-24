USE [bodb_HRM]
GO

-- Update Deleted Employee's ResignedDate
UPDATE [dbo].[Employee]
SET [IsDeleted] = 1
WHERE [UserId] IN (
    999, 552, 553, 554, 4381, 4382, 4383, 4384, 4386, 4387, 
    4437, 4601, 4535, 4536, 4537, 4538, 4539, 4542, 4543, 4544, 4555
)
GO

-- Update ResignedDate based on last attendance date or JoinedDate
UPDATE e
SET e.ResignedDate = COALESCE(
    (SELECT MAX(a.AttendanceDate)
     FROM [dbo].[EmployeeAttendance] a
     WHERE a.EmpId = e.EmpId),
    e.JoinedDate
)
FROM [dbo].[Employee] e
WHERE [UserId] IN (
    1056, 142, 886, 667, 726, 904, 952, 662, 331, 4, 145, 160, 164, 167, 600, 725, 1029,
    4378, 4380, 4385, 4420, 4424, 4428, 4429, 4434, 4436, 4438, 4442, 4456, 4457, 4458,
    4461, 4467, 4470, 4524, 4656, 4685, 4686, 4687, 4695, 4696, 4699, 4700, 4701, 4753,
    5133, 5134, 5135, 5136, 5137, 5138, 4598, 4599, 4600, 2515, 2520, 2525, 2529, 2530,
    2532, 2537, 2539, 2541, 2542, 2550, 2552, 2553, 2586, 2601, 2604, 2608, 2609, 2610,
    2611, 2612, 2613, 2614, 2615, 2618, 2619, 2621, 2622, 2623, 2624, 2625, 2626, 2627,
    2628, 2629, 2630, 2632, 2633, 2635, 2636, 2637, 2638, 2639, 2641, 2643, 2644, 2646,
    2648, 2649, 2651, 2652, 2748, 2767, 3777, 3778, 3912, 3944, 4030, 4032, 4035, 4093,
    4094, 4109, 4131, 4155, 4173, 4196, 4197
)
GO

-- Update JoinedDate based on first attendance date
UPDATE e
SET e.JoinedDate = (
    SELECT MIN(a.AttendanceDate)
    FROM [dbo].[EmployeeAttendance] a
    WHERE a.EmpId = e.EmpId
)
FROM [dbo].[Employee] e
WHERE [UserId] IN (2603)
GO

