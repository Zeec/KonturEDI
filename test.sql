--UPDATE KonturEDI.dbo.edi_Messages SET IsProcessed = 0 WHERE messageId ='725AF034-D4C2-48BB-A5A2-EE1D967E1452'

EXEC tpsrv_logon
EXEC external_EDIKontur

--EXEC xp_dirtree 'c:\kontur\inbox', 1, 1
--exec external_ImportORDRSP 'c:\kontur\inbox\'

--SELECT * FROM KonturEDI.dbo.edi_Messages
--SELECT * FROM KonturEDI.dbo.edi_MessagesLog

/*declare @xml xml = '<statusReport reportDateTime="2015-08-27T18:55:24.223" reportRecipient="2000000009780" reportItem_x002F_messageId="7b505121-92a3-42c5-a975-dafd9a83fcac" reportItem_x002F_documentId="7b505121-92a3-42c5-a975-dafd9a83fcac" reportItem_x002F_messageSender="2000000009759" reportItem_x002F_messageRecepient="2000000009780" reportItem_x002F_documentType="ORDRSP" reportItem_x002F_documentNumber="JC4UC75M5O5CPK4BH" reportItem_x002F_documentDate="2015-08-27" reportItem_x002F_statusItem_x002F_dateTime="2015-08-27T18:55:24.223" reportItem_x002F_statusItem_x002F_stage="Checking" reportItem_x002F_statusItem_x002F_state="Fail" reportItem_x002F_statusItem_x002F_description="При обработке сообщения произошла ошибка" reportItem_x002F_statusItem_x002F_error="Изменение заказов не поддерживается учетной системой"/>'
select @xml

rollback tran*/