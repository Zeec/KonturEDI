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

DECLARE @OutboxPath NVARCHAR(255), @InboxPath NVARCHAR(255), @idtp_ID_GTIN UNIQUEIDENTIFIER
SELECT @OutboxPath = OutboxPath, @InboxPath = InboxPath, @idtp_ID_GTIN = idtp_ID_GTIN FROM KonturEDI.dbo.edi_Settings


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
		DECLARE
			 @strqt_Name NVARCHAR(MAX)
			,@strqt_Date DATETIME
		
		SELECT @strqt_Name = strqt_Name, @strqt_Date = strqt_Date FROM StoreRequests WHERE strqt_ID = @doc_ID
		SET @strqt_Name = @strqt_Name+'_'+REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, GETDATE(), 120), ':', ''), '-', ''), ' ', '')
		
		UPDATE StoreRequests 
		SET  strqt_strqtst_ID = 10
			,strqt_Name = @strqt_Name
		WHERE strqt_ID = @doc_ID

		UPDATE KonturEDI.dbo.edi_Messages 
		SET doc_Name = @strqt_Name  
		WHERE doc_ID = @doc_ID

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
			,n.value('orderedQuantity[1]', 'NUMERIC(18, 6)') AS 'orderedQuantity'
			,n.value('orderedQuantity[1]/@unitOfMeasure', 'NVARCHAR(MAX)') AS 'orderedQuantity_unitOfMeasure'
			,n.value('confirmedQuantity[1]', 'NUMERIC(18, 6)') AS 'confirmedQuantity'
			,n.value('confirmedQuantity[1]/@unitOfMeasure', 'NVARCHAR(MAX)') AS 'confirmedQuantity_unitOfMeasure'
			,n.value('onePlaceQuantity[1]', 'NVARCHAR(MAX)') AS 'onePlaceQuantity'
			,n.value('onePlaceQuantity[1]/@unitOfMeasure', 'NVARCHAR(MAX)') AS 'onePlaceQuantity_unitOfMeasure'
			,n.value('expireDate[1]', 'NVARCHAR(MAX)') AS 'expireDate'
			,n.value('manufactoringDate[1]', 'NVARCHAR(MAX)') AS 'manufactoringDate'
			,n.value('netPrice[1]', 'NUMERIC(18, 6)') AS 'netPrice'
			,n.value('netPriceWithVAT[1]', 'NUMERIC(18, 6)') AS 'netPriceWithVAT'
			,n.value('netAmount[1]', 'NUMERIC(18, 6)') AS 'netAmount'
			,n.value('exciseDuty[1]', 'NUMERIC(18, 6)') AS 'exciseDuty'
			,n.value('vATRate[1]', 'NUMERIC(18, 6)') AS 'vATRate'
			,n.value('vATAmount[1]', 'NUMERIC(18, 6)') AS 'vATAmount'
			,n.value('amount[1]', 'NUMERIC(18, 6)') AS 'amount'
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

		-- SELECT * FROM #MessageItems	

		-- Новая заявка
		DECLARE @strqt_ID UNIQUEIDENTIFIER = NEWID()
		-- Позиции заявки
		DECLARE
			 @strqti_ID uniqueidentifier
			,@strqti_ID_orig uniqueidentifier
			-- ,@strqti_strqt_ID uniqueidentifier
			,@strqti_pitm_ID uniqueidentifier
			,@strqti_meit_ID uniqueidentifier
			,@strqti_strqtist_ID int
			,@strqti_IdentifierCode nvarchar(max) 
			,@strqti_ItemName nvarchar(max) 
			,@strqti_Article nvarchar(max) 
			,@strqti_idtp_ID uniqueidentifier 
			,@strqti_Remains numeric(18, 6) 
			,@strqti_ConsumptionPerDay numeric(18, 6) 
			,@strqti_Volume NUMERIC(18, 6)
			,@strqti_Price numeric(30, 10) 
			,@strqti_Sum numeric(18, 4) 
			,@strqti_VAT numeric(18, 3) 
			,@strqti_SumVAT numeric(18, 4) 
			,@strqti_EditIndex int 
			,@strqti_Comment nvarchar(max) 
			,@strqti_Order int 
			,@meit_Rate numeric(18, 6)
		DECLARE
			 @status NVARCHAR(MAX)
			,@gtin NVARCHAR(MAX)
			,@internalBuyerCode NVARCHAR(MAX)
			,@internalSupplierCode NVARCHAR(MAX)
			,@serialNumber NVARCHAR(MAX)
			,@orderLineNumber NVARCHAR(MAX)
			,@typeOfUnit NVARCHAR(MAX)
			,@description NVARCHAR(MAX)
			,@comment NVARCHAR(MAX)
			,@orderedQuantity NVARCHAR(MAX)
			,@orderedQuantity_unitOfMeasure NVARCHAR(MAX)
			,@confirmedQuantity NVARCHAR(MAX)
			,@confirmedQuantity_unitOfMeasure NVARCHAR(MAX)
			,@onePlaceQuantity NVARCHAR(MAX)
			,@onePlaceQuantity_unitOfMeasure NVARCHAR(MAX)
			,@expireDate NVARCHAR(MAX)
			,@manufactoringDate NVARCHAR(MAX)
			,@netPrice NVARCHAR(MAX)
			,@netPriceWithVAT NVARCHAR(MAX)
			,@netAmount NVARCHAR(MAX)
			,@exciseDuty NVARCHAR(MAX)
			,@vATRate NVARCHAR(MAX)
			,@vATAmount NVARCHAR(MAX)
			,@amount  NVARCHAR(MAX)
		
		INSERT INTO StoreRequests (strqt_ID,strqt_strqtyp_ID,strqt_stor_ID_In,strqt_stor_ID_Out,strqt_part_ID_Out,strqt_usr_ID,strqt_strqtst_ID,strqt_DateInput,strqt_DateLimit,strqt_Date,strqt_Name,strqt_Description)
	    SELECT @strqt_ID, strqt_strqtyp_ID, strqt_stor_ID_In, strqt_stor_ID_Out, strqt_part_ID_Out, strqt_usr_ID, strqt_strqtst_ID, strqt_DateInput, strqt_DateLimit, strqt_Date, @doc_Name, strqt_Description 
		FROM StoreRequests WHERE strqt_ID = @doc_ID

		DECLARE @tmp NVARCHAR(MAX) =  'Создана на основе заявки N '+@strqt_Name
		EXEC external_UpdateDocStatus @strqt_ID, @doc_Type, @tmp
        
		-- WHERE 
		-- Позиции заявки
		/*INSERT INTO StoreRequestItems (strqti_ID,strqti_strqt_ID,strqti_pitm_ID,strqti_meit_ID,strqti_strqtist_ID,strqti_IdentifierCode,strqti_ItemName,strqti_Article,strqti_idtp_ID,strqti_Remains,strqti_ConsumptionPerDay,strqti_Volume,strqti_Price,strqti_Sum,strqti_VAT,strqti_SumVAT,strqti_EditIndex,strqti_Comment,strqti_Order)
		SELECT NEWID(),@strqt_ID,strqti_pitm_ID,strqti_meit_ID,CASE WHEN status = 'Rejected' THEN 2 ELSE 0 END 'strqti_strqtist_ID',strqti_IdentifierCode,strqti_ItemName,strqti_Article,strqti_idtp_ID,strqti_Remains,strqti_ConsumptionPerDay,strqti_Volume,strqti_Price,strqti_Sum,strqti_VAT,strqti_SumVAT,strqti_EditIndex,strqti_Comment,strqti_Order
		FROM #MessageItems
		-- связка по GTIN
		JOIN tp_StoreRequestItems ON strqti_idtp_ID = @tralala AND strqti_IdentifierCode = gtin 
		*/

		DECLARE ci CURSOR FOR
			SELECT status,gtin ,internalBuyerCode ,internalSupplierCode ,serialNumber ,orderLineNumber ,typeOfUnit ,description ,comment ,orderedQuantity 
			,orderedQuantity_unitOfMeasure ,confirmedQuantity ,confirmedQuantity_unitOfMeasure ,onePlaceQuantity ,onePlaceQuantity_unitOfMeasure ,expireDate 
			,manufactoringDate ,netPrice ,netPriceWithVAT ,netAmount ,exciseDuty ,vATRate ,vATAmount ,amount  
			FROM #MessageItems
		OPEN ci
		FETCH ci INTO @status,@gtin ,@internalBuyerCode ,@internalSupplierCode ,@serialNumber ,@orderLineNumber ,@typeOfUnit ,@description ,@comment ,@orderedQuantity 
			,@orderedQuantity_unitOfMeasure ,@confirmedQuantity ,@confirmedQuantity_unitOfMeasure ,@onePlaceQuantity ,@onePlaceQuantity_unitOfMeasure ,@expireDate 
			,@manufactoringDate ,@netPrice ,@netPriceWithVAT ,@netAmount ,@exciseDuty ,@vATRate ,@vATAmount ,@amount  
		WHILE @@FETCH_STATUS = 0 BEGIN
			-- Ищем позицию заявки по GTIN в заявке 
			SELECT @strqti_ID_orig = strqti_ID 
			FROM tp_StoreRequestItems 
			WHERE strqti_strqt_ID = @doc_ID AND strqti_IdentifierCode = @gtin AND strqti_idtp_ID = @idtp_ID_GTIN

			-- Второй поиск через товарные номенклатуры (если заменили)

			-- Позиция заявки найдена, нужно обработать статусы
			IF @strqti_ID_orig IS NOT NULL BEGIN
				-- Новые значения для заявки
				SELECT 
					 @strqti_ID = NEWID()
					-- ,@strqti_strqt_ID
					,@strqti_pitm_ID = strqti_pitm_ID
					,@strqti_meit_ID = strqti_meit_ID
					,@strqti_strqtist_ID = strqti_strqtist_ID
					,@strqti_IdentifierCode = strqti_IdentifierCode
					,@strqti_ItemName = strqti_ItemName
					,@strqti_Article = strqti_Article
					,@strqti_idtp_ID = strqti_idtp_ID
					,@strqti_Remains = strqti_Remains
					,@strqti_ConsumptionPerDay = strqti_ConsumptionPerDay
					,@strqti_Volume = strqti_Volume
					,@strqti_Price = strqti_Price
					,@strqti_Sum = strqti_Sum
					,@strqti_VAT = strqti_VAT
					,@strqti_SumVAT = strqti_SumVAT
					,@strqti_EditIndex = strqti_EditIndex
					,@strqti_Comment = strqti_Comment
					,@strqti_Order = strqti_Order
					,@meit_Rate = MI.meit_Rate
				FROM StoreRequestItems  I
				JOIN ProductItems            P ON P.pitm_ID = I.strqti_pitm_ID
				JOIN tp_MeasureItems            MI ON MI.meit_ID = strqti_meit_ID
				WHERE strqti_ID = @strqti_ID_orig

				IF @status = 'Changed' BEGIN
					SET @strqti_Comment = 'Изменено поставщиком: '
					IF @strqti_Volume <> @confirmedQuantity*@meit_Rate
						SET @strqti_Comment = @strqti_Comment + ' Кол-во ['+CONVERT(NVARCHAR(MAX), CONVERT(NUMERIC(18,2), @strqti_Volume/@meit_Rate))+'->'+CONVERT(NVARCHAR(MAX), CONVERT(NUMERIC(18,2), @confirmedQuantity))+']'
					IF @strqti_Price <> @netPrice/@meit_Rate
						SET @strqti_Comment = @strqti_Comment + ' Цена ['+CONVERT(NVARCHAR(MAX), CONVERT(NUMERIC(18,2), @strqti_Price*@meit_Rate))+'->'+CONVERT(NVARCHAR(MAX), CONVERT(NUMERIC(18,2), @netPrice))+']'

					SELECT
						 @strqti_Volume = @confirmedQuantity*@meit_Rate
						,@strqti_Price = @netPrice/@meit_Rate
						,@strqti_Sum = @netAmount
						,@strqti_VAT = CONVERT(NUMERIC(18,6), @vATRate)/100
						,@strqti_SumVAT = @vATAmount
				END
				ELSE IF @status = 'Rejected' BEGIN
					SELECT 
						 @strqti_Volume = 0
						,@strqti_Comment = 'Отвергнута поставщиком'
				END
				ELSE IF @status = 'Accepted' BEGIN
					SELECT 
						@strqti_Comment = 'Принята поставщиком'
				END
				-- Вставляем обработанные значения
				
				INSERT INTO StoreRequestItems (strqti_ID,strqti_strqt_ID,strqti_pitm_ID,strqti_meit_ID,strqti_strqtist_ID,strqti_IdentifierCode,strqti_ItemName,strqti_Article,strqti_idtp_ID,strqti_Remains,strqti_ConsumptionPerDay,strqti_Volume,strqti_Price,strqti_Sum,strqti_VAT,strqti_SumVAT,strqti_EditIndex,strqti_Comment,strqti_Order)
				VALUES (@strqti_ID, @strqt_ID, @strqti_pitm_ID, @strqti_meit_ID, @strqti_strqtist_ID, @strqti_IdentifierCode, @strqti_ItemName, @strqti_Article, @strqti_idtp_ID, @strqti_Remains, @strqti_ConsumptionPerDay, @strqti_Volume, @strqti_Price, @strqti_Sum, @strqti_VAT, @strqti_SumVAT, @strqti_EditIndex, @strqti_Comment, @strqti_Order)
				
			END
			-- Если не нашли позицию заявки
			ELSE BEGIN
				EXEC tpsys_RaiseError 50001, 'Не найдена позиция заявки. Пока ошибка, возможно нужно делать создание новой позиции'
			END

		FETCH ci INTO @status,@gtin ,@internalBuyerCode ,@internalSupplierCode ,@serialNumber ,@orderLineNumber ,@typeOfUnit ,@description ,@comment ,@orderedQuantity 
			,@orderedQuantity_unitOfMeasure ,@confirmedQuantity ,@confirmedQuantity_unitOfMeasure ,@onePlaceQuantity ,@onePlaceQuantity_unitOfMeasure ,@expireDate 
			,@manufactoringDate ,@netPrice ,@netPriceWithVAT ,@netAmount ,@exciseDuty ,@vATRate ,@vATAmount ,@amount  
		END

		CLOSE ci
		DEALLOCATE ci

		IF EXISTS (
			SELECT * FROM StoreRequestItems I1
			LEFT JOIN StoreRequestItems I2 ON I2.strqti_ID = I1.strqti_ID
			WHERE I1.strqti_strqt_ID = @doc_ID AND I2.strqti_strqt_ID = @strqt_ID AND I2.strqti_ID IS NULL)
			
			EXEC tpsys_RaiseError 50001, 'Пришли не все позиции заявки'

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
        EXEC @R = master..xp_cmdshell @cmd, NO_OUTPUT

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
