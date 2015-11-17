return--
--tpsrv_start
EXEC tpsrv_logon 'sv', '1'
--BEGIN TRAN
EXEC external_ImportORDRSP 
--commit tran
SELECT * FROM KonturEDI.dbo.edi_Errors
return

BEGIN TRAN
EXEC external_EDIKontur '152335FE-8572-BE44-882F-C005BB6FE82F'
commit tran
EXEC external_ImportORDRSP 'c:\Kontur\Inbox\'

select * from KonturEDI.dbo.edi_Errors

-- EXEC external_EDIKontur '152335FE-8572-BE44-882F-C005BB6FE82F'
--EXEC external_PrepareORDERS
select convert(datetimeoffset, '2015-11-11T08:49:29.911Z+3')
select convert(datetimeoffset, GETDATE())
select * from KonturEDI.dbo.edi_MessagesLog order by log_Date desc --WHERE doc_ID ='1AAB28C7-314E-1645-B289-605B226C7CD7'
select top 5 * from KonturEDI.dbo.edi_Messages order by message_creationDateTime desc
--delete from KonturEDI.dbo.edi_Messages where doc_ID = 'C6E1C66B-A187-6046-AF21-AEFF44CFB677'
SELECT strqt_ID, strqt_Name, strqt_Date, 'request'
	FROM StoreRequests R 
	LEFT JOIN KonturEDI.dbo.edi_Messages M ON doc_ID = strqt_ID
	WHERE strqt_strqtyp_ID IN (11,12)
		AND strqt_strqtst_ID = 12 
		AND M.doc_ID IS NULL
	ORDER BY strqt_Date DESC
 	
	EXEC tpsrv_logon 'sv', '1'
	update StoreRequests SET strqt_strqtst_ID = 13 WHERE strqt_ID = '1F079669-3EB9-9A4A-BA05-7C65AC3576D1'
	
	--select * from tp_Tasks
--
/*DECLARE @cmd VARCHAR(200)
SET @cmd = 'C:\kontur\Actions\get_reports.cmd'
EXEC master..xp_cmdshell @cmd*/



















--select * from KonturEDI.dbo.edi_Messages  WHERE messageId ='5010A02A-BCD3-4BC6-9C9F-5FD320D5F7BD'

/*UPDATE KonturEDI.dbo.edi_Messages 
SET message_filename = 'C:\Kontur\Outbox\RECADV_1B2E573D-13E5-4C8B-931C-F65A5D8E1546.xml'
where message_ID = '1B2E573D-13E5-4C8B-931C-F65A5D8E1546'*/

--DECLARE @cmd VARCHAR(2000)
--SET @cmd = 'C:\kontur\actions\get_reports.cmd'
--EXEC master..xp_cmdshell @cmd, no_output

--EXEC xp_dirtree 'C:\kontur\Reports\', 1, 1

--EXEC external_ExportORDERS 

/*select * from KonturEDI.dbo.edi_Messages where doc_ID = 'EE76B5FC-09C2-C444-88E2-19B72A463A75'
--select * from tp_StoreRequests

SELECT strqt_ID, strqt_Name, strqt_Date, 'request', m.* 
FROM tp_StoreRequests 
LEFT JOIN KonturEDI.dbo.edi_Messages M ON doc_ID = strqt_ID
WHERE strqt_strqtyp_ID = 12 
    AND strqt_strqtst_ID = 12 
	AND M.doc_ID IS NULL
ORDER BY strqt_Date DESC

select cast('<eDIMessage id="57E7DF62-186D-47FB-9030-5309DF93948F" creationDateTime="2015-11-09T12:04:55.527"><interchangeHeader><sender>2000000009759</sender><recipient>2000000009780</recipient><documentType>ORDERS</documentType><creationDateTime>2015-11-09T12:04:55.527</creationDateTime><creationDateTimeBySender>2015-11-09T12:04:55.527</creationDateTimeBySender></interchangeHeader><order number="163" date="2015-11-09" id="B567314D-AAAE-F84E-8023-2FF52783BCA6" status="Original"><contractIdentificator number="1" date="2015-10-01"/><seller><gln>2000000009780</gln></seller><buyer><gln>2000000009759</gln></buyer><deliveryInfo><requestedDeliveryDateTime>2015-11-29T11:14:00</requestedDeliveryDateTime><shipFrom><gln>2000000009780</gln></shipFrom><shipTo><gln>2000000009759</gln></shipTo></deliveryInfo><lineItems><currencyISOCode>RUB</currencyISOCode><lineItem><internalBuyerCode>1AB80E75-7DB7-CD4F-B077-A0E2DEC1E42E</internalBuyerCode><lineNumber>3</lineNumber><description>Окорок куриный</description><requestedQuantity unitOfMeasure="KGM">1.000000</requestedQuantity><netPrice>150.0000000000</netPrice><netPriceWithVAT>150.000000</netPriceWithVAT><netAmount>150.0000</netAmount><VATRate>0.000</VATRate><VATAmount>0.0000</VATAmount><amount>150.0000</amount></lineItem><lineItem><gtin>13</gtin><internalBuyerCode>DB5B517E-CB82-3F43-B23E-1C14BA75CBBB</internalBuyerCode><internalSupplierCode>010101</internalSupplierCode><lineNumber>1</lineNumber><description>Молоко Галактика</description><requestedQuantity unitOfMeasure="PCE">5.000000</requestedQuantity><netPrice>200.0000000000</netPrice><netPriceWithVAT>220.000000</netPriceWithVAT><netAmount>1000.0000</netAmount><VATRate>10.000</VATRate><VATAmount>100.0000</VATAmount><amount>1100.0000</amount></lineItem><lineItem><gtin>222222222</gtin><internalBuyerCode>D897DF82-5025-4843-97A8-64D0486840A0</internalBuyerCode><internalSupplierCode>121211</internalSupplierCode><lineNumber>2</lineNumber><description>Творог 0 %</description><requestedQuantity unitOfMeasure="KGM">11.000000</requestedQuantity><netPrice>11.0000000000</netPrice><netPriceWithVAT>11.000000</netPriceWithVAT><netAmount>121.0000</netAmount><VATRate>0.000</VATRate><VATAmount>0.0000</VATAmount><amount>121.0000</amount></lineItem><totalSumExcludingTaxes>1271.0000</totalSumExcludingTaxes><totalVATAmount>100.0000</totalVATAmount><totalAmount>1371.0000</totalAmount></lineItems></order></eDIMessage>'
as xml)*/
-- EXEC external_EDIKontur

--select * from tp_NoteTypes where nttp_pagecaption = 'EDIKontur'
--select * from tp_NoteTypeObjects where nttpo_nttp_ID = '74d6e928-475b-4f4c-8bc7-c216def422d6'

--select * from  KonturEDI.dbo.edi_MessagesLog where doc_ID = '86920DB0-8B1F-0642-82C8-96ED99A62865' order by log_Date
--select * from  KonturEDI.dbo.edi_MessagesLog  order by log_Date desc

--select * from  KonturEDI.dbo.edi_Messages order by doc_Date
--select * from InputDocuments order by idoc_Date where idoc_ID = 'DBD04B8E-76DE-4AAF-9BA1-56F291C13F6A'
--select * from InputDocumentItems where idit_idoc_ID = 'DBD04B8E-76DE-4AAF-9BA1-56F291C13F6A'
--EXEC external_CreateInputFromRequest '86920DB0-8B1F-0642-82C8-96ED99A62865', 400
/*

delete from KonturEDI.dbo.edi_MessagesLog where doc_ID = '86920DB0-8B1F-0642-82C8-96ED99A62865'
delete from KonturEDI.dbo.edi_Messages where doc_ID = '86920DB0-8B1F-0642-82C8-96ED99A62865'

*/

--select CONVERT(NVARCHAR(MAX), ISNULL(GETDATE(), GETDATE()), 126),  CONVERT(NVARCHAR(MAX), ISNULL(GETDATE(), GETDATE()), 127)
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
FOR XML Path('params'),Type
<params>
  <param type="name">rpc</param>
  <param type="number">1</param>
  <param type="type">A  </param>
</params>
*/