IF OBJECT_ID(N'external_CreateInputFromRequest', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_CreateInputFromRequest
GO

CREATE PROCEDURE dbo.external_CreateInputFromRequest (
    @strqt_ID UNIQUEIDENTIFIER)
AS
/*
DECLARE @PARAMETER_stor_ID_Value_0 UNIQUEIDENTIFIER
DECLARE @PARAMETER_part_ID_Value_0 UNIQUEIDENTIFIER
DECLARE @PARAMETER_usr_ID_Value_0 UNIQUEIDENTIFIER
DECLARE @PARAMETER_Date_Value_0 DATETIME
DECLARE @PARAMETER_DocID_0 UNIQUEIDENTIFIER

SET @PARAMETER_stor_ID_Value_0 = '38A9C1B0-BA75-434F-ADCC-94A665B40770'
SET @PARAMETER_part_ID_Value_0 = '46BA7DB7-0BC1-214E-B704-7ADE47283009'
SET @PARAMETER_usr_ID_Value_0 = '942AF580-6AE9-4D89-9465-7A348FB604E9'
SET @PARAMETER_Date_Value_0 = CONVERT(DATETIME,'2015-10-21 17:24:39.330',21)
SET @PARAMETER_DocID_0 = '288C2F78-3328-A540-869E-C3C0947D9C8C'

IF OBJECT_ID('tempdb..#NAMETABLE') IS NOT NULL DROP TABLE #NAMETABLE
CREATE TABLE #NAMETABLE (Name NVARCHAR(100))

IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL DROP TABLE #RESULT
CREATE TABLE #RESULT (ID UNIQUEIDENTIFIER, Name NVARCHAR(100))

EXEC tpsrv_SetValueAsGUID 'stor_ID', 'q_GetDocumentNumber1', @PARAMETER_stor_ID_Value_0, 0
EXEC tpsrv_SetValueAsGUID 'part_ID', 'q_GetDocumentNumber1', @PARAMETER_part_ID_Value_0, 0
EXEC tpsrv_SetValueAsGUID 'usr_ID', 'q_GetDocumentNumber1', @PARAMETER_usr_ID_Value_0, 0
EXEC tpsrv_SetValueAsDATETIME 'Date', 'q_GetDocumentNumber1', @PARAMETER_Date_Value_0, 0

EXEC tpsrv_ExecuteQuery 'q_GetDocumentNumber1', %QueryID
EXEC tpsrv_AssignStreams 'q_GetDocumentNumber1', 'q_GetDocumentNumber2' 

INSERT #NAMETABLE EXEC tpsrv_SelectTableValue 'Main', 'q_GetDocumentNumber2'

INSERT #RESULT (ID, Name)
SELECT @PARAMETER_DocID_0, Name
FROM #NAMETABLE

DELETE #NAMETABLE

SELECT ID, Name
FROM #RESULT

DROP TABLE #NAMETABLE
DROP TABLE #RESULT
*/


DECLARE 
  @idoc_ID UNIQUEIDENTIFIER,
  @idoc_Name NVARCHAR(MAX),
  @idoc_Date DATETIME

SELECT @idoc_ID = NEWID(), @idoc_Name = strqt_Name, @idoc_Date = GETDATE()
FROM StoreRequests
WHERE strqt_ID = @strqt_ID

IF OBJECT_ID('tempdb..#StoreRequestItemInputDocumentItems') IS NOT NULL DROP TABLE #StoreRequestItemInputDocumentItems

CREATE TABLE #StoreRequestItemInputDocumentItems (
	sriidi_ID UNIQUEIDENTIFIER,
	sriidi_strqti_ID UNIQUEIDENTIFIER,
	sriidi_idit_ID UNIQUEIDENTIFIER,
	sriidi_Volume NUMERIC(18, 6))

INSERT INTO #StoreRequestItemInputDocumentItems (sriidi_ID, sriidi_strqti_ID, sriidi_idit_ID, sriidi_Volume)
SELECT NEWID(), strqti_ID, NEWID(), strqti_Volume
FROM StoreRequestItems
WHERE strqti_strqt_ID = @strqt_ID

-- Приход
INSERT INTO InputDocuments (idoc_ID, idoc_stor_ID, idoc_part_ID, idoc_usr_ID, idoc_idst_ID, idoc_sens_ID, idoc_Date, idoc_Name, idoc_ExternalName, idoc_Description)
SELECT @idoc_ID, strqt_stor_ID_In, strqt_part_ID_Out, strqt_usr_ID, 0, 0,  @idoc_Date, @idoc_Name, NULL, 'Автоматически создано'
FROM StoreRequests
WHERE strqt_ID = @strqt_ID

-- Позиции
INSERT INTO InputDocumentItems (idit_ID, idit_idoc_ID, idit_pitm_ID, idit_meit_ID, idit_ItemName, idit_Article, 
    idit_idtp_ID, idit_IdentifierCode, idit_Volume, idit_Price, idit_Sum, idit_VAT, idit_SumVAT, idit_EditIndex, 
	idit_Comment, idit_Order)
SELECT T.sriidi_idit_ID, @idoc_ID, strqti_pitm_ID, strqti_meit_ID, strqti_ItemName, strqti_Article, 
    strqti_idtp_ID, strqti_IdentifierCode, strqti_Volume, strqti_Price, strqti_Sum, strqti_VAT, strqti_SumVAT, strqti_EditIndex,
    strqti_Comment, strqti_Order
FROM #StoreRequestItemInputDocumentItems T
JOIN StoreRequestItems                   I ON I.strqti_ID = T.sriidi_ID

-- Связки
INSERT INTO StoreRequestItemInputDocumentItems (sriidi_ID, sriidi_strqti_ID, sriidi_idit_ID, sriidi_Volume)
SELECT sriidi_ID, sriidi_strqti_ID, sriidi_idit_ID, sriidi_Volume
FROM #StoreRequestItemInputDocumentItems

-- Сообщение
INSERT INTO KonturEDI.dbo.edi_Messages (doc_ID, doc_Name, doc_Date, doc_Type, doc_ID_original)
SELECT @idoc_ID, @idoc_Name, @idoc_Date, 'input', @strqt_ID
