SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


IF OBJECT_ID(N'external_ExportStatusReport', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_ExportStatusReport
GO

CREATE PROCEDURE dbo.external_ExportStatusReport (
     @FilePath NVARCHAR(MAX)
    ,@FileName_Original NVARCHAR(MAX)
    ,@state NVARCHAR(MAX)
    ,@description NVARCHAR(MAX)
	,@error NVARCHAR(MAX) = NULL)
AS
/*
    Формирование статусного сообщения
	На входе ожидается таблица #Messages   
*/

DECLARE @TRANCOUNT INT
--DECLARE @messageId UNIQUEIDENTIFIER
DECLARE @FileName SYSNAME, @Result_XML XML, @Result_Text NVARCHAR(MAX)

SET @TRANCOUNT = @@TRANCOUNT
IF @TRANCOUNT = 0
    BEGIN TRAN external_ExportStatusReport
ELSE
    SAVE TRAN external_ExportStatusReport

BEGIN TRY
    SET @Result_XML = (
	    SELECT 
		   GETDATE() N'reportDateTime'
		  ,senderGLN N'reportRecipient'
		  ,messageId N'reportItem/messageId'
		  ,messageId N'reportItem/documentId'
		  ,senderGLN N'reportItem/messageSender'
		  ,recipientGLN N'reportItem/messageRecepient'
		  ,documentType N'reportItem/documentType'
		  ,msg_number N'reportItem/documentNumber'
		  ,msg_date N'reportItem/documentDate'
		  ,GETDATE() N'reportItem/statusItem/dateTime'
		  ,'Checking' N'reportItem/statusItem/stage'
		  ,@state N'reportItem/statusItem/state'
		  ,@description N'reportItem/statusItem/description'
		  ,@error N'reportItem/statusItem/error'
        FROM #Messages
		FOR XML PATH(N'statusReport'), TYPE
	)
  	  
    SET @Result_Text = N'<?xml version="1.0" encoding="utf-8"?>' + CONVERT(NVARCHAR(MAX), @Result_XML)

	SET @FileName = @FilePath+@state+REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, GETDATE(), 120), ':', ''), '-', ''), ' ', '')+'_'+CAST(@FileName_Original AS NVARCHAR(MAX))+'.xml'
	EXEC dbo.external_SaveToFile @FileName, @Result_Text

	--SET @File = @FilePath + @state + '_' + CAST(@messageId AS NVARCHAR(MAX)) + '.xml'
	-- сообщение в логи
    --INSERT INTO KonturEDI.dbo.edi_Messages (doc_ID, doc_Name, doc_Date, doc_Type)
	--UPDATE KonturEDI.dbo.edi_Messages SET IsProcessed = 1 WHERE messageId = @messageId
	--SELECT CAST(@Result AS XML)

 	IF @TRANCOUNT = 0 
  	    COMMIT TRAN
END TRY
BEGIN CATCH
    -- Ошибка загрузки файла, пишем ошибку приема
	IF @@TRANCOUNT > 0
	    IF (XACT_STATE()) = -1
	        ROLLBACK
	    ELSE
	        ROLLBACK TRAN external_ExportStatusReport
	IF @TRANCOUNT > @@TRANCOUNT
	    BEGIN TRAN

	EXEC tpsys_ReraiseError
END CATCH
