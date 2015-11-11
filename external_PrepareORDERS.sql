SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'external_PrepareORDERS ', 'P') IS NOT NULL
  DROP PROCEDURE dbo.external_PrepareORDERS
GO

CREATE PROCEDURE dbo.external_PrepareORDERS 
WITH EXECUTE AS OWNER
AS
DECLARE @TRANCOUNT INT

-- Необработанные заказы
SET @TRANCOUNT = @@TRANCOUNT
IF @TRANCOUNT = 0 
    BEGIN TRAN external_PrepareORDERS
ELSE              
    SAVE TRAN external_PrepareORDERS

BEGIN TRY
	INSERT INTO KonturEDI.dbo.edi_Messages (doc_ID, doc_Name, doc_Date, doc_Type)
	SELECT strqt_ID, strqt_Name, strqt_Date, 'request'
	FROM StoreRequests R 
	LEFT JOIN KonturEDI.dbo.edi_Messages M ON doc_ID = strqt_ID
	WHERE strqt_strqtyp_ID IN (11,12)
		AND strqt_strqtst_ID = 12 
		AND M.doc_ID IS NULL
	ORDER BY strqt_Date DESC
 	
	IF @TRANCOUNT = 0
  		COMMIT TRAN
END TRY
BEGIN CATCH
	-- Ошибка загрузки файла, пишем ошибку приема
	IF @@TRANCOUNT > 0
		IF (XACT_STATE()) = -1
			ROLLBACK
		ELSE
			ROLLBACK TRAN external_ExportORDERS1
	IF @TRANCOUNT > @@TRANCOUNT
		BEGIN TRAN

	-- Ошибки в таблицу, обработаем потом
	INSERT INTO KonturEDI.dbo.edi_Errors (ProcedureName, ErrorNumber, ErrorMessage)
	SELECT 'external_PrepareORDERS', ERROR_NUMBER(), ERROR_MESSAGE()
	EXEC tpsys_ReraiseError
END CATCH
