USE TastyBytesDB;

GO

CREATE TABLE TastyBytes.EmployeeShift (
    ShiftID         INT IDENTITY(1,1),
    EmployeeName    NVARCHAR(200) NOT NULL,
    TruckID         INT NOT NULL,
    ShiftDate       DATE NOT NULL,
    StartTime       DATETIME NOT NULL,
    EndTime         DATETIME NOT NULL,
    HoursWorked     AS (DATEDIFF(MINUTE, StartTime, EndTime) / 60.0),
    Role            VARCHAR(50) NOT NULL DEFAULT 'Cook',
    HourlyRate      SMALLMONEY NOT NULL,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE()
);
