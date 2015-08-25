--external_CreateOrdersXML

IF OBJECT_ID(N'external_CreateOrdersXML', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_CreateOrdersXML
GO

CREATE PROCEDURE dbo.external_CreateOrdersXML (
    @messageId UNIQUEIDENTIFIER)
AS

/*SELECT	'name'		AS [param/@type]
,	 name		AS [param/text()]
,	NULL		AS [*]
,	'number'	AS [param/@type]
,	 number		AS [param/text()]
,	NULL		AS [*]
,	'type'		AS [param/@type]
,	[type]		AS [param/text()]
FROM	master.dbo.spt_values
WHERE	type = 'A'
FOR XML Path('eDIMessage'),Type
<params>
  <param type="name">rpc</param>
  <param type="number">1</param>
  <param type="type">A  </param>
</params>
*/

/*SELECT messageId AS [eDIMessage/@id]
    ,creationDateTime AS [eDIMessage/@creationDateTime]
	,'a' AS [eDIMessage/interchangeHeader/@r]
FROM KonturEDI.dbo.edi_Messages
FOR XML Path(''), TYPE*/
/*
USE DBZee_9_5_0
SELECT * FROM tp_StoreRequests

insert into KonturEDI.dbo.edi_Messages (doc_ID)
VALUES ('E0D262BC-2301-8245-99EB-309CC2802351')

SELECT * FROM KonturEDI.dbo.edi_Messages WHERE doc_ID = 'E0D262BC-2301-8245-99EB-309CC2802351'

*/

--USE DBZee_9_5_0


-- DECLARE @messageId UNIQUEIDENTIFIER = 'FB9D17A1-AC52-4200-A87C-FA78E95A33FD'

DECLARE @LineItem XML, @LineItems XML


-- Элементы заказа
SET @LineItem = (
SELECT 
     P.pitm_Article N'gtin' -- GTIN товара
    ,P.pitm_ID N'internalBuyerCode' --внутренний код присвоенный покупателем
	,I.strqti_Article N'internalSupplierCode' --артикул товара (код товара присвоенный продавцом)
	,I.strqti_Order N'lineNumber' --порядковый номер товара
	,NULL N'typeOfUnit' --признак возвратной тары, если это не тара, то строки нет
	,dbo.f_MultiLanguageStringToStringByLanguage1(ISNULL(I.strqti_ItemName, P.pitm_Name), 25) N'description' --название товара
	,dbo.f_MultiLanguageStringToStringByLanguage1(I.strqti_Comment, 25) N'comment' --комментарий к товарной позиции
	-- ,dbo.f_MultiLanguageStringToStringByLanguage1(MI.meit_Name, 25) N'requestedQuantity/@unitOfMeasure' -- MeasurementUnitCode
	,'PCE' N'requestedQuantity/@unitOfMeasure' -- MeasurementUnitCode
	,I.strqti_Volume N'requestedQuantity/text()' --заказанное количество
	,NULL N'onePlaceQuantity/@unitOfMeasure' -- MeasurementUnitCode
	,NULL N'onePlaceQuantity/text()' -- количество в одном месте (чему д.б. кратно общее кол-во)
--	,'Direct' N'flowType' --Тип поставки, может принимать значения: Stock - сток до РЦ, Transit - транзит в магазин, Direct - прямая поставка, Fresh - свежие продукты
	,I.strqti_Price N'netPrice' --цена товара без НДС
	,I.strqti_Price+I.strqti_Price*I.strqti_VAT N'netPriceWithVAT' --цена товара с НДС
	,I.strqti_Sum N'netAmount' --сумма по позиции без НДС
	--,NULL N'exciseDuty' --акциз товара
	,I.strqti_VAT*100 N'VATRate' --ставка НДС (NOT_APPLICABLE - без НДС, 0 - 0%, 10 - 10%, 18 - 18%)
	,I.strqti_SumVAT N'VATAmount' --сумма НДС по позиции
	,I.strqti_Sum+I.strqti_SumVAT N'amount' --сумма по позиции с НДС
FROM KonturEDI.dbo.edi_Messages M
JOIN tp_StoreRequestItems       I ON I.strqti_strqt_ID = M.doc_ID
JOIN tp_ProductItems            P ON P.pitm_ID = I.strqti_pitm_ID
JOIN tp_MeasureItems            MI ON MI.meit_ID = strqti_meit_ID
WHERE M.messageId = @messageId  --'AA215039-87FE-4EA6-B9B4-CAFE688864D1'
FOR XML PATH(N'lineItem'), TYPE)



SET @LineItems = (
SELECT
     'RUB' N'currencyISOCode' --код валюты (по умолчанию рубли)
	,@LineItem
    ,SUM(strqti_Sum) N'totalSumExcludingTaxes' -- сумма заявки без НДС
	,SUM(strqti_SumVAT) N'totalVATAmount' -- сумма НДС по заказу
	,SUM(strqti_Sum + strqti_SumVAT) N'totalAmount' -- --общая сумма заказа всего с НДС
FROM KonturEDI.dbo.edi_Messages M
JOIN tp_StoreRequests           R ON R.strqt_ID = M.doc_ID
JOIN tp_StoreRequestItems       I ON I.strqti_strqt_ID = M.doc_ID
WHERE M.messageId = @messageId
FOR XML PATH(N'lineItems'), TYPE)


-- seller
DECLARE 
     @part_ID_Out UNIQUEIDENTIFIER
	,@part_ID_Self UNIQUEIDENTIFIER
	,@addr_ID UNIQUEIDENTIFIER

DECLARE @seller XML, @buyer XML, @invoicee XML, @deliveryInfo XML
DECLARE @strqt_DateInput DATETIME

SELECT TOP 1 
     -- Поставщик
     @part_ID_Out = R.strqt_part_ID_Out
	 -- Своя организация
	,@part_ID_Self = G.stgr_part_ID
	-- Адрес склада
	,@addr_ID = addr_ID
	,@strqt_DateInput = strqt_DateInput
FROM KonturEDI.dbo.edi_Messages M
JOIN tp_StoreRequests           R ON R.strqt_ID = M.doc_ID
-- Склады
JOIN tp_Stores      S ON S.stor_ID = strqt_stor_ID_In
JOIN tp_StoreGroups G ON G.stgr_ID = S.stor_stgr_ID
-- Своя организация
-- LEFT JOIN tp_Partners SelfParnter ON SelfParnter.part_ID = stgr_part_ID
-- Адрес склада
LEFT JOIN Addresses               ON addr_obj_ID         = S.stor_loc_ID
WHERE M.messageId = @messageId





EXEC dbo.external_GetSellerXML @part_ID_Out, @seller OUTPUT
EXEC dbo.external_GetBuyerXML @part_ID_Self, @addr_ID, @buyer OUTPUT
--EXEC external_GetInvoiceeXML @part_ID, @invoicee OUTPUT
EXEC external_GetDeliveryInfoXML @part_ID_Self, @strqt_DateInput, @deliveryInfo OUTPUT

DECLARE @senderGLN NVARCHAR(MAX), @buyerGLN NVARCHAR(MAX)
SET @senderGLN = @seller.value('(/seller/gln)[1]', 'NVARCHAR(MAX)')
SET @buyerGLN = @buyer.value('(/buyer/gln)[1]', 'NVARCHAR(MAX)')

SELECT @senderGLN , @buyerGLN
-- SELECT @buyer
--return

DECLARE @Result NVARCHAR(MAX)
SET @Result=
	--N'<?xml  version ="1.0"  encoding ="utf-8"?>'+
	(
		SELECT
			messageId N'id', 
            creationDateTime N'creationDateTime',
			(
				SELECT
					@buyerGLN N'sender',
					@senderGLN N'recipient',
					'ORDERS' N'documentType'
					,creationDateTime N'creationDateTime'
					,creationDateTime N'creationDateTimeBySender'
					,1 'IsTest'
				FOR XML PATH(N'interchangeHeader'), TYPE
			)
			,(
			    SELECT 
				--номер документа-заказа, дата документа-заказа, статус документа - оригинальный/отменённый/копия/замена, номер исправления для заказа-замены
				   R.strqt_Name N'@number'
				   ,GETDATE() N'@date'
				   ,N'Original' N'@status'
				   ,NULL N'@revisionNumber'
				   
				   ,NULL N'promotionDealNumber'
				   ,@seller
				   ,@buyer
				   ,@invoicee
				   ,@deliveryInfo
				   ,@lineItems

				FOR XML PATH(N'order'), TYPE
            
			)

        FROM KonturEDI.dbo.edi_Messages M
		JOIN tp_StoreRequests           R ON R.strqt_ID = M.doc_ID
		WHERE M.messageId = @messageId
		FOR XML RAW(N'EDIMessage')
	)

-- SELECT @Result 'FileData'
-- SELECT CAST(@Result AS XML) 'FileData'

DECLARE @File SYSNAME, @R NVARCHAR(MAX)

SET @R = N'<?xml  version ="1.0"  encoding ="utf-8"?>'+@Result


SET @File = 'C:\kontur\Outbox\ORDERS_'+CAST(@messageId AS NVARCHAR(MAX))+'.xml'
EXEC dbo.external_SaveToFile @File, @R

SET @File = 'C:\Zee\Текущее\0_Срочное\Kontur\box\ORDERS_'+CAST(@messageId AS NVARCHAR(MAX))+'.xml'
EXEC dbo.external_SaveToFile @File, @R

SELECT CAST(@Result AS XML)

