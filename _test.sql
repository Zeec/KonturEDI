--UPDATE KonturEDI.dbo.edi_Messages SET IsProcessed = 0 WHERE messageId ='725AF034-D4C2-48BB-A5A2-EE1D967E1452'

/*UPDATE KonturEDI.dbo.edi_Messages 
SET IsProcessed = 0
where doc_ID = '21134842-0515-46DA-889C-A005D2503505'*/

EXEC tpsrv_logon 'sv', '1'
EXEC external_EDIKontur

--select newid()
/*
select * from tp_Notetypes
-- C8AC8FD2-77AF-3F48-B476-0255C9562FA7 дата
-- EA463965-C7AE-144F-AACD-2DCF0D3A9695 номер

DECLARE @messageId UNIQUEIDENTIFIER

SELECT TOP 1 @messageId = messageId 
FROM KonturEDI.dbo.edi_Messages M
JOIN InputDocuments I ON I.idoc_ID = M.doc_ID
WHERE doc_Type = 'input' AND IsProcessed = 0  AND idoc_idst_ID = 1

EXEC external_ExportRECADV @messageId,  'C:\kontur\Outbox'*/

--EXEC xp_dirtree 'c:\kontur\inbox', 1, 1
--exec external_ImportORDRSP 'c:\kontur\inbox\'


--SELECT * FROM KonturEDI.dbo.edi_Messages where doc_ID = '21134842-0515-46DA-889C-A005D2503505'
--SELECT * FROM KonturEDI.dbo.edi_MessagesLog
-- select * from tp_InputDocuments where idoc_date > '28.10.2015' -- idoc_ID = 'D5ED4B3E-32D9-4890-B726-51AF26478C71'
-- select * from tp_InputDocumentItems where idit_idoc_ID = 'D5ED4B3E-32D9-4890-B726-51AF26478C71'
-- select * from tp_users where usr_ID = '942AF580-6AE9-4D89-9465-7A348FB604E9'
/*declare @xml xml = '<statusReport reportDateTime="2015-08-27T18:55:24.223" reportRecipient="2000000009780" reportItem_x002F_messageId="7b505121-92a3-42c5-a975-dafd9a83fcac" reportItem_x002F_documentId="7b505121-92a3-42c5-a975-dafd9a83fcac" reportItem_x002F_messageSender="2000000009759" reportItem_x002F_messageRecepient="2000000009780" reportItem_x002F_documentType="ORDRSP" reportItem_x002F_documentNumber="JC4UC75M5O5CPK4BH" reportItem_x002F_documentDate="2015-08-27" reportItem_x002F_statusItem_x002F_dateTime="2015-08-27T18:55:24.223" reportItem_x002F_statusItem_x002F_stage="Checking" reportItem_x002F_statusItem_x002F_state="Fail" reportItem_x002F_statusItem_x002F_description="При обработке сообщения произошла ошибка" reportItem_x002F_statusItem_x002F_error="Изменение заказов не поддерживается учетной системой"/>'
select @xml

rollback tran*/

--SELECT CONVERT(XML, '<EDIMessage id="76FD7277-625B-4482-9F46-445C7060A381" creationDateTime="2015-10-21T15:38:37.390"><interchangeHeader><sender>2000000009759</sender><recipient>2000000009780</recipient><documentType>ORDERS</documentType><creationDateTime>2015-10-21T15:38:37.390</creationDateTime><creationDateTimeBySender>2015-10-21T15:38:37.390</creationDateTimeBySender><documentId>1</documentId></interchangeHeader><order number="8" date="2015-08-20T14:00:02.113" id="7D591F23-33D9-8844-A22C-82402A5D98EC" status="Original"><seller><gln>2000000009780</gln><organization><name>Тестовый поставщик Тиллипад</name><inn>11111111111111111111111111</inn><kpp>222222222222222222222222</kpp></organization><russianAddress><city>СПб</city></russianAddress><additionalIdentificator>46BA7DB7-0BC1-214E-B704-7ADE47283009</additionalIdentificator><additionalInfo><phone>92111111111</phone><nameOfCEO>Земсков Сергей </nameOfCEO><orderContact>Земсков Сергей </orderContact></additionalInfo></seller><buyer><gln>2000000009759</gln><organization><name>Тестовая сеть Тиллипад</name><inn>7825107438</inn><kpp>781632001</kpp></organization><russianAddress><city>Санкт-Петербург</city><street>Яхтенная</street><house>22</house><flat>377</flat><postalCode>195000</postalCode></russianAddress><contactlInfo><CEO><orderContact>3699999</orderContact><fax/><email>smolinets@tillypad.ru</email></CEO></contactlInfo></buyer><deliveryInfo><requestedDeliveryDateTime>2015-08-23T00:00:00</requestedDeliveryDateTime><shipFrom><gln>2000000009780</gln></shipFrom><shipTo><gln>2000000009759</gln><russianAddress><city>Санкт-Петербург</city><street>Яхтенная</street><house>22</house><flat>377</flat><postalCode>195000</postalCode></russianAddress></shipTo></deliveryInfo><lineItems><currencyISOCode>RUB</currencyISOCode><lineItem><gtin>13</gtin><internalBuyerCode>DB5B517E-CB82-3F43-B23E-1C14BA75CBBB</internalBuyerCode><internalSupplierCode>010101</internalSupplierCode><lineNumber>1</lineNumber><description>Молоко Галактика</description><requestedQuantity unitOfMeasure="PCE">2.000000</requestedQuantity><netPrice>100.0000000000</netPrice><netPriceWithVAT>100.000000</netPriceWithVAT><netAmount>200.0000</netAmount><VATRate>0.000</VATRate><VATAmount>0.0000</VATAmount><amount>200.0000</amount></lineItem><totalSumExcludingTaxes>200.0000</totalSumExcludingTaxes><totalVATAmount>0.0000</totalVATAmount><totalAmount>200.0000</totalAmount></lineItems></order></EDIMessage>')
--select getdate()

 --SELECT CONVERT(DATE, doc_Date)
--	  FROM  KonturEDI.dbo.edi_Messages --ON doc_Name = originOrder_number AND  = CONVERT(DATE, originOrder_date)

 --UPDATE StoreRequests SET strqt_strqtst_ID = 11 
 --SELECT * FROM StoreRequests WHERE strqt_ID = '9B0D52DB-2864-E54D-B8D5-EAB5EB804DF3' -- 10 не готова, 12 отправлена 11 подтв

 -- SELECT * FROM InputDocuments WHERE idoc_NAme = '102' 
 
 /*SELECT * 
 FROM InputDocuments 
 join inputdocumentitems ON idit_idoc_ID = idoc_ID 
 join StoreRequestItemInputDocumentItems on sriidi_idit_ID = idit_ID
 WHERE idoc_NAme = '102' 

 StoreRequestItemLinks
 StoreRequestItemInputDocumentItems */

/*
go
tpsrv_stop
go
tpsrv_start
go
*/

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