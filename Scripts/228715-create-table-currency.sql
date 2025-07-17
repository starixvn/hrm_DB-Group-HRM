USE bodb_HRM
GO

CREATE TABLE Currency (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    CurrencyCode VARCHAR(3) NOT NULL UNIQUE
);

INSERT INTO Currency (CurrencyCode)
VALUES 
('CNY'),
('EUR'),
('GBP'),
('MYR'),
('NTD'),
('PHP'),
('SGD'),
('THB'),
('USD'),
('VND');