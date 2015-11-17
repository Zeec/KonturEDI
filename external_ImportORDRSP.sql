SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('external_ImportORDRSP', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_ImportORDRSP
GO

CREATE PROCEDURE dbo.external_ImportORDRSP (
  @Path1 NVARCHAR(255) = NULL)
WITH EXECUTE AS OWNER
AS

-- Прием сообщений
DECLARE @doc_ID UNIQUEIDENTIFIER, @doc_Type NVARCHAR(MAX), @message_ID UNIQUEIDENTIFIER, @doc_Name NVARCHAR(MAX)

DECLARE @fname NVARCHAR(255), @full_fname NVARCHAR(255),  @Text NVARCHAR(255), @xml xml, @sql NVARCHAR(MAX), @cmd NVARCHAR(255), @R INT
DECLARE @t TABLE (fname NVARCHAR(255), d INT, f INT)
DECLARE @TRANCOUNT INT

DECLARE @Result_XML XML, @Result_Text NVARCHAR(MAX), @FileName SYSNAME
DECLARE @msg_status NVARCHAR(MAX)

DECLARE @OutboxPath NVARCHAR(255), @InboxPath NVARCHAR(255)
SELECT @OutboxPath = OutboxPath, @InboxPath = InboxPath FROM KonturEDI.dbo.edi_Settings


-- получаем список файлов для закачки (заказы)
INSERT INTO @t (fname, d, f) EXEC xp_dirtree @InboxPath, 1, 1

-- идем по списку
DECLARE ct CURSOR FOR
  SELECT fname, @InboxPath+'\'+fname AS full_fname FROM @t WHERE f=1 AND fname LIKE 'ORDRSP%'

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
	  n.value('@id', 'NVARCHAR(MAX)') AS 'msgId',
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
 	SELECT @msg_status = NULL, @message_ID = NULL, @doc_ID = NULL,@doc_Type = NULL, @doc_Name = NULL
	
	-- По какому документу пришли данные
 	SELECT @msg_status = msg_status,@message_ID = message_Id,@doc_ID = doc_ID,@doc_Type = doc_Type, @doc_Name = doc_Name
	FROM #Messages
	LEFT JOIN KonturEDI.dbo.edi_Messages ON doc_Name = originOrder_number AND CONVERT(DATE, doc_Date) = CONVERT(DATE, originOrder_date)

	IF @doc_ID IS NULL BEGIN 
		SELECT @Text = 'Не найден документ N'+originOrder_number+' от '+originOrder_date FROM #Messages
		EXEC tpsys_RaiseError 50001, @Text
	END
	-- Лог
	INSERT INTO KonturEDI.dbo.edi_MessagesLog (log_XML, log_Text, message_ID, doc_ID) 
	VALUES (@xml, 'Получено подтверждение заказа', @message_ID, @doc_ID)

    -- Accepted/Rejected/Changed
	IF @msg_status = 'Changed' BEGIN
		-- Поставить статус "Не готова" у оринальной заявки
		UPDATE StoreRequests 
		SET  strqt_strqtst_ID = 10
			,strqt_Name = strqt_Name+'_'+REPLACE(CONVERT(NVARCHAR(MAX), GETDATE(), 108), ':', '')
		WHERE strqt_ID = @doc_ID

		-- Обновляем дополнительный статус
		EXEC external_UpdateDocStatus @doc_ID, @doc_Type, 'Пришли изменения от поставщика'

		-- Собираем таблицу с изменениями
		IF OBJECT_ID('tempdb..#MessageItems') IS NOT NULL 
			DROP TABLE #MessageItems 
		
		SELECT 
			 n.value('@status', 'NVARCHAR(MAX)') AS 'status'
			,n.value('gtin[1]', 'NVARCHAR(MAX)') AS 'gtin' --GTIN товара
			,n.value('internalBuyerCode[1]', 'NVARCHAR(MAX)') AS 'internalBuyerCode'
			,n.value('internalSupplierCode[1]', 'NVARCHAR(MAX)') AS 'internalSupplierCode'
			,n.value('serialNumber[1]', 'NVARCHAR(MAX)') AS 'serialNumber'
			,n.value('orderLineNumber[1]', 'NVARCHAR(MAX)') AS 'orderLineNumber'
			,n.value('typeOfUnit[1]', 'NVARCHAR(MAX)') AS 'typeOfUnit'
			,n.value('description[1]', 'NVARCHAR(MAX)') AS 'description'
			,n.value('comment[1]', 'NVARCHAR(MAX)') AS 'comment'
			,n.value('orderedQuantity[1]', 'NVARCHAR(MAX)') AS 'orderedQuantity'
			,n.value('orderedQuantity[1]/@unitOfMeasure', 'NVARCHAR(MAX)') AS 'orderedQuantity_unitOfMeasure'
			,n.value('confirmedQuantity[1]', 'NVARCHAR(MAX)') AS 'confirmedQuantity'
			,n.value('confirmedQuantity[1]/@unitOfMeasure', 'NVARCHAR(MAX)') AS 'confirmedQuantity_unitOfMeasure'
			,n.value('onePlaceQuantity[1]', 'NVARCHAR(MAX)') AS 'onePlaceQuantity'
			,n.value('onePlaceQuantity[1]/@unitOfMeasure', 'NVARCHAR(MAX)') AS 'onePlaceQuantity_unitOfMeasure'
			,n.value('expireDate[1]', 'NVARCHAR(MAX)') AS 'expireDate'
			,n.value('manufactoringDate[1]', 'NVARCHAR(MAX)') AS 'manufactoringDate'
			,n.value('netPrice[1]', 'NVARCHAR(MAX)') AS 'netPrice'
			,n.value('netPriceWithVAT[1]', 'NVARCHAR(MAX)') AS 'netPriceWithVAT'
			,n.value('netAmount[1]', 'NVARCHAR(MAX)') AS 'netAmount'
			,n.value('exciseDuty[1]', 'NVARCHAR(MAX)') AS 'exciseDuty'
			,n.value('vATRate[1]', 'NVARCHAR(MAX)') AS 'vATRate'
			,n.value('vATAmount[1]', 'NVARCHAR(MAX)') AS 'vATAmount'
			,n.value('amount[1]', 'NVARCHAR(MAX)') AS 'amount'
  /*      <gtin>GTIN</gtin>   <-->
        <internalBuyerCode>BuyerProductId</internalBuyerCode>   <!--внутренний код присвоенный покупателем-->
        <internalSupplierCode>SupplierProductId</internalSupplierCode>  <!--артикул товара (код товара присвоенный продавцом)-->
		<serialNumber>SerialNumber</serialNumber>  <!--серийный номер товара-->
        <orderLineNumber>orderLineNumber</orderLineNumber>  <!--номер позиции в заказе-->
        <typeOfUnit>RС</typeOfUnit>   <!--признак возвратной тары, если это не тара, то строки нет-->        
		<description>Name</description>   <!--название товара-->

        <comment>LineItemComment</comment> <!--комментарий к товарной позиции-->
        <orderedQuantity unitOfMeasure="MeasurementUnitCode">OrdersQuantity</orderedQuantity>    <!--заказанное количество-->
        <confirmedQuantity unitOfMeasure="MeasurementUnitCode">OrdrspQuantity</confirmedQuantity>    <!--подтвержденнное количество-->
        <onePlaceQuantity unitOfMeasure="MeasurementUnitCode">OnePlaceQuantity</onePlaceQuantity>  <!-- количество в одном месте (чему д.б. кратно общее кол-во) -->

        <expireDate>expireDate</expireDate>  <!--срок годности-->		
		<manufactoringDate>manufactoringDate</manufactoringDate>  <!--дата производства-->
        <netPrice>Price</netPrice>    <!--цена товара без НДС-->
        <netPriceWithVAT>Price</netPriceWithVAT>     <!--цена товара с НДС-->
        <netAmount>PriceSummary</netAmount>     <!--сумма по позиции без НДС-->
        <exciseDuty>exciseSum</exciseDuty>     <!--акциз товара-->
        <vATRate>VATRate</vATRate>     <!--ставка НДС (NOT_APPLICABLE - без НДС, 0 - 0%, 10 - 10%, 18 - 18%)-->
        <vATAmount>VATSummary</vATAmount>    <!--сумма НДС по позиции-->
        <amount>PriceSummaryWithVAT</amount>   <!--сумма по позиции с НДС-->
*/
		--INTO #MessageItems
		INTO #MessageItems
		FROM @xml.nodes('/eDIMessage/orderResponse/lineItems/lineItem') t(n)

		SELECT * FROM #MessageItems	

		-- Новая заявка
		DECLARE @strqt_ID UNIQUEIDENTIFIER = NEWID()
		
		INSERT INTO StoreRequests (strqt_ID,strqt_strqtyp_ID,strqt_stor_ID_In,strqt_stor_ID_Out,strqt_part_ID_Out,strqt_usr_ID,strqt_strqtst_ID,strqt_DateInput,strqt_DateLimit,strqt_Date,strqt_Name,strqt_Description)
	    SELECT @strqt_ID, strqt_strqtyp_ID, strqt_stor_ID_In, strqt_stor_ID_Out, strqt_part_ID_Out, strqt_usr_ID, strqt_strqtst_ID, strqt_DateInput, strqt_DateLimit, strqt_Date, @doc_Name, strqt_Description 
		FROM StoreRequests WHERE strqt_ID = @doc_ID
	
        -- WHERE 
		-- Позиции заявки
		INSERT INTO StoreRequestItems (strqti_ID,strqti_strqt_ID,strqti_pitm_ID,strqti_meit_ID,strqti_strqtist_ID,strqti_IdentifierCode,strqti_ItemName,strqti_Article,strqti_idtp_ID,strqti_Remains,strqti_ConsumptionPerDay,strqti_Volume,strqti_Price,strqti_Sum,strqti_VAT,strqti_SumVAT,strqti_EditIndex,strqti_Comment,strqti_Order)
		SELECT NEWID(),@strqt_ID,strqti_pitm_ID,strqti_meit_ID,CASE WHEN status = 'Rejected' THEN 2 ELSE 0 END 'strqti_strqtist_ID',strqti_IdentifierCode,strqti_ItemName,strqti_Article,strqti_idtp_ID,strqti_Remains,strqti_ConsumptionPerDay,strqti_Volume,strqti_Price,strqti_Sum,strqti_VAT,strqti_SumVAT,strqti_EditIndex,strqti_Comment,strqti_Order
		FROM #MessageItems
		-- связка по GTIN
		JOIN tp_StoreRequestItems ON strqti_idtp_ID = @tralala AND strqti_IdentifierCode = gtin 

		DECLARE ci CURSOR FOR
			SELECT [status],[gtin],[internalBuyerCode],[internalSupplierCode],[serialNumber],[orderLineNumber],[typeOfUnit],[description],[comment],[orderedQuantity],[orderedQuantity_unitOfMeasure],[confirmedQuantity],[confirmedQuantity_unitOfMeasure],[onePlaceQuantity],[onePlaceQuantity_unitOfMeasure],[expireDate],[manufactoringDate],[netPrice],[netPriceWithVAT],[netAmount],[exciseDuty],[vATRate],[vATAmount],[amount]
			FROM #MessageItems
		OPEN ci
		FETCH ci INTO @message_ID, @doc_ID --, @doc_Name, @doc_Date, @doc_Type

		WHILE @@FETCH_STATUS = 0 BEGIN 

			FETCH ci INTO @message_ID, @doc_ID --, @doc_Name, @doc_Date, @doc_Type
		END

		CLOSE ci
		DEALLOCATE ci

/*		BEGIN
			-- Нет позиции оригинальной заявки, нужно создать новую на основе пришедших данных (наверно и такое может случится)
			IF @strqti_ID IS NULL BEGIN
			    -- Ищем 
				SELECT parpit_pitm_ID
				FROM tp_PartnerProductItems 
				JOIN tp_PartnerProductItemIdentifiers ON parpidnt_parpit_ID = parpit_ID AND parpidnt_idtp_ID = @tralala
				WHERE parpidnt_Code = @gtin AND parpit_part_ID = @blablabla

				INSERT 
			END
			--
			--
		END
*/
		-- FULL JOIN (SELECT * FROM StoreRequestItems WHERE strqti_strqt_ID = @doc_ID) A ON CONVERT(NVARCHAR(MAX),strqti_pitm_ID) = internalBuyerCode 
		-- JOIN StoreRequestItems ON CONVERT(NVARCHAR(MAX),strqti_pitm_ID) = internalBuyerCode
        -- WHERE strqti_strqt_ID = @doc_ID

		-- Изменение заказов не поддерживается учетной системой
        -- EXEC external_ExportStatusReport @message_ID, @doc_ID, @OutboxPath, @fname, 'Fail', 'При обработке сообщения произошла ошибка', 'Изменение заказов не поддерживается учетной системой'
	END
	ELSE IF @msg_status = 'Rejected' BEGIN
 	  -- Поставить статус "заказ отменен"
	  UPDATE StoreRequests SET strqt_strqtst_ID = 10 WHERE strqt_ID = @doc_ID
      
	  EXEC external_UpdateDocStatus @doc_ID, @doc_Type, 'Отвергнута'

      EXEC external_ExportStatusReport @message_ID, @doc_ID, @OutboxPath, @fname, 'Ok', 'Сообщение доставлено'
	END
	ELSE IF @msg_status = 'Accepted' BEGIN
		-- Меняем статус на "Подтверждена"
		UPDATE StoreRequests SET strqt_strqtst_ID = 11 WHERE strqt_ID = @doc_ID

		EXEC external_UpdateDocStatus @doc_ID, @doc_Type, 'Принята'

		EXEC external_ExportStatusReport @message_ID, @doc_ID, @OutboxPath, @fname, 'Ok', 'Сообщение доставлено'
	END

	    -- Сообщение обработано, удаляем
        SET @cmd = 'DEL /f /q "'+ @full_fname+'"'
        -- EXEC @R = master..xp_cmdshell @cmd, NO_OUTPUT

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

	    -- Ошибки в таблицу, обработаем потом 
		INSERT INTO KonturEDI.dbo.edi_Errors (ProcedureName, ErrorNumber, ErrorMessage)
	    SELECT 'ImportORDRSP', ERROR_NUMBER(), ERROR_MESSAGE()
	    --EXEC tpsys_ReraiseError
    END CATCH
  
    IF OBJECT_ID('tempdb..#Messages') IS NOT NULL 
        DROP TABLE #Messages 
 
    FETCH ct INTO @fname, @full_fname
END

CLOSE ct
DEALLOCATE ct

GO
