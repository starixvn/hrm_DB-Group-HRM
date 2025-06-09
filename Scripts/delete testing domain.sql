use [bodb_HRM]
go

delete
from dbo.CompanySite
where Domain IN (
    'https://hrm-new.sms-vn.com',
    'https://hrm-new.comtechsb.com',
    'https://hrm-new.sandsdover.com',
    'https://hrm-new.xpeedcorp.com',
    'https://hrm-new.elementsc.ph',
    'https://hrm-new.connectshorecorp.com',
    'https://hrm-new.ghrworld.com',
    'https://hrm-new.cymabell.com'
)