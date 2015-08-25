IF OBJECT_ID('external_EDIKontur', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_EDIKontur
GO

CREATE PROCEDURE dbo.external_EDIKontur
WITH EXECUTE AS OWNER
AS

SELECT * FROM KonturEDI.dbo.edi_Messages
SELECT * FROM KonturEDI.dbo.edi_MessagesLog

INSERT INTO KonturEDI.dbo.edi_Messages (doc_ID)
SELECT strqt_ID 
FROM tp_StoreRequests
WHERE strqt_strqtyp_ID = 12 
    AND strqt_strqtst_ID = 12
	AND strqt_ID NOT IN (SELECT doc_ID FROM KonturEDI.dbo.edi_Messages)

DECLARE @messageId UNIQUEIDENTIFIER
SELECT TOP 1 @messageId = messageId FROM KonturEDI.dbo.edi_Messages WHERE IsProcessed = 0
SELECT @messageId

IF @messageId IS NOT NULL
  EXEC external_CreateOrdersXML @messageId

UPDATE KonturEDI.dbo.edi_Messages SET IsProcessed = 1 WHERE messageId = @messageId
-- EXEC tpsrv_logon

EXEC external_ImportReports 'C:\kontur\Reports'

/*USE DBZee_9_5_0
SELECT * FROM tp_StoreRequests
WHERE strqt_ID not in (SELECT doc_ID FROM KonturEDI.dbo.edi_Messages)

DECLARE @doc_ID UNIQUEIDENTIFIER = '46B555A6-1A06-0944-B7A8-06FF67EC0687'

insert into KonturEDI.dbo.edi_Messages (doc_ID)
VALUES (@doc_ID)

SELECT * FROM KonturEDI.dbo.edi_Messages WHERE doc_ID = @doc_ID

*/
GO

--UPDATE KonturEDI.dbo.edi_Messages SET IsProcessed = 1 WHERE messageId = 'c02c2241-0f83-4133-889b-85058a078589'
SELECT * FROM KonturEDI.dbo.edi_Messages  WHERE doc_Id = '46BA7DB7-0BC1-214E-B704-7ADE47283009'

