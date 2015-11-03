SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('external_ImportORDRSP', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_ImportORDRSP
GO

CREATE PROCEDURE dbo.external_ImportORDRSP (
  @Path NVARCHAR(255))
WITH EXECUTE AS OWNER
AS
-- Прием сообщений
DECLARE @doc_ID UNIQUEIDENTIFIER, @doc_Type NVARCHAR(MAX), @messageId UNIQUEIDENTIFIER

DECLARE @fname NVARCHAR(255), @full_fname NVARCHAR(255),  @Text NVARCHAR(255), @xml xml, @sql NVARCHAR(MAX), @cmd NVARCHAR(255), @R INT
DECLARE @t TABLE (fname NVARCHAR(255), d INT, f INT)
DECLARE @TRANCOUNT INT

DECLARE @Result_XML XML, @Result_Text NVARCHAR(MAX), @FileName SYSNAME
DECLARE @msg_status NVARCHAR(MAX)

-- получаем список файлов для закачки (заказы)
INSERT INTO @t (fname, d, f) EXEC xp_dirtree @Path, 1, 1

-- идем по списку
DECLARE ct CURSOR FOR
  SELECT fname, @Path+'\'+fname AS full_fname FROM @t WHERE f=1 AND fname LIKE 'ORDRSP%'

OPEN ct
FETCH ct INTO @fname, @full_fname

WHILE @@FETCH_STATUS = 0 BEGIN
  
  IF OBJECT_ID('tempdb..#Messages') IS NOT NULL 
    DROP TABLE #Messages 

  SET @xml = NULL
  SET @SQL = 'SELECT @xml = CAST(x.data as XML) FROM OPENROWSET(BULK '+QUOTENAME(@full_fname, CHAR(39))+' , SINGLE_BLOB) AS x(data)'
  EXEC sp_executesql @SQL, N'@xml xml out', @xml = @xml OUT
 
  SET @TRANCOUNT = @@TRANCOUNT
  IF @TRANCOUNT = 0
	BEGIN TRAN external_ImportORDRSP
  ELSE
	SAVE TRAN external_ImportORDRSP

  BEGIN TRY
	-- Сообщение ORDRSP
    SELECT 
	  n.value('@id', 'NVARCHAR(MAX)') AS 'messageId',
	  n.value('interchangeHeader[1]/sender[1]', 'NVARCHAR(MAX)') AS 'senderGLN',
	  n.value('interchangeHeader[1]/recipient[1]', 'NVARCHAR(MAX)') AS 'recipientGLN', 
	  n.value('interchangeHeader[1]/documentType[1]', 'NVARCHAR(MAX)') AS 'documentType', 
	  n.value('orderResponse[1]/@number', 'NVARCHAR(MAX)') AS 'msg_number',
	  n.value('orderResponse[1]/@date', 'NVARCHAR(MAX)') AS 'msg_date',
	  n.value('orderResponse[1]/@status', 'NVARCHAR(MAX)') AS 'msg_status',
      n.value('orderResponse[1]/originOrder[1]/@number', 'NVARCHAR(MAX)') AS 'originOrder_number',
      n.value('orderResponse[1]/originOrder[1]/@date', 'NVARCHAR(MAX)') AS 'originOrder_date'
    INTO #Messages
    FROM @xml.nodes('/eDIMessage') t(n)

	-- Надо бы проверку на свои GLN

	
	SELECT @msg_status = msg_status FROM #Messages

 	SELECT @doc_ID = doc_ID, @doc_Type = doc_Type
	FROM #Messages
	JOIN KonturEDI.dbo.edi_Messages ON doc_Name = originOrder_number AND CONVERT(DATE, doc_Date) = CONVERT(DATE, originOrder_date)

    -- Accepted/Rejected/Changed
	IF @msg_status = 'Changed' BEGIN
	    -- Изменение заказов не поддерживается учетной системой
        EXEC external_ExportStatusReport 'C:\Kontur\Outbox\', @fname, 'Fail', 'При обработке сообщения произошла ошибка', 'Изменение заказов не поддерживается учетной системой'
	END
	ELSE IF @msg_status = 'Rejected' BEGIN
 	  -- Поставить статус "заказ отменен"
	  UPDATE StoreRequests SET strqt_strqtst_ID = 10 WHERE strqt_ID = @doc_ID
      
	  EXEC external_UpdateDocStatus @doc_ID, @doc_Type, 'Отвергнута'

      EXEC external_ExportStatusReport 'C:\Kontur\Outbox\', @fname, 'Ok', 'Сообщение доставлено'
	END
	ELSE IF @msg_status = 'Accepted' BEGIN
	  -- Меняем статус на "Подтверждена"
	  UPDATE tp_StoreRequests SET strqt_strqtst_ID = 11 WHERE strqt_ID = @doc_ID

	  EXEC external_UpdateDocStatus @doc_ID, @doc_Type, 'Принята'

      EXEC external_ExportStatusReport 'C:\Kontur\Outbox\', @fname, 'Ok', 'Сообщение доставлено'
	END

    SET @cmd = 'DEL /f /q "'+ @full_fname+'"'
    EXEC @R = master..xp_cmdshell @cmd 

 	IF @TRANCOUNT = 0 
  	  COMMIT TRAN
  END TRY
  BEGIN CATCH
    -- Ошибка загрузки файла, пишем ошибку приема
	IF @@TRANCOUNT > 0
	  IF (XACT_STATE()) = -1
	    ROLLBACK
	  ELSE
	    ROLLBACK TRAN external_ImportORDRSP
	IF @TRANCOUNT > @@TRANCOUNT
	  BEGIN TRAN

	EXEC tpsys_ReraiseError
  END CATCH
  
  IF OBJECT_ID('tempdb..#Messages') IS NOT NULL 
    DROP TABLE #Messages 
 
  FETCH ct INTO @fname, @full_fname
END

CLOSE ct
DEALLOCATE ct

GO
