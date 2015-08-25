IF OBJECT_ID(N'external_GetDeliveryInfoXML', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_GetDeliveryInfoXML
GO

CREATE PROCEDURE dbo.external_GetDeliveryInfoXML  (
    @part_ID UNIQUEIDENTIFIER,
	-- @addr_ID UNIQUEIDENTIFIER,
	@requestedDeliveryDateTime DATETIME,
	@DeliveryInfoXML XML OUTPUT)
AS
/*
    <!-- начало блока данных о грузоотправителе и грузополучателе -->
    <deliveryInfo>
      <requestedDeliveryDateTime>deliveryOrdersDateT00:00:00.000Z</requestedDeliveryDateTime>   <!--дата доставки по заявке (заказу)-->
      <exportDateTimeFromSupplier>shipmentOrdersDateT00:00:00.000Z</exportDateTimeFromSupplier>   <!--дата вывоза товара от поставщика-->
      <shipFrom>
        <gln>ShipperGln</gln>  <!--gln грузоотправителя-->
        <organization>
          <name>ShipperName</name>  <!--наименование грузоотправителя-->
          <inn>ShipperInn(10)</inn>
          <kpp>ShipperKpp</kpp>
        </organization>
        <russianAddress>  <!--российский адрес-->
          <regionISOCode>RegionCode</regionISOCode>
          <district>district</district>
          <city>City</city>
          <settlement>Village</settlement>
          <street>Street</street>
          <house>House</house>
          <flat>Flat</flat>
          <postalCode>>PostalCode</postalCode>
        </russianAddress>
        <additionalInfo>
          <phone>TelephoneNumber</phone>   <!--телефон контактного лица-->
          <fax>FaxNumber</fax>     <!--факс контактного лица-->
          <bankAccountNumber>BankAccountNumber</bankAccountNumber>
          <bankName>BankName</bankName>
          <BIK>BankId</BIK>
          <nameOfAccountant>BookkeeperName</nameOfAccountant>       <!--ФИО бухгалтера-->
        </additionalInfo>
      </shipFrom>
      <shipTo>
        <gln>DeliveryGln</gln>  <!--gln грузополучателя-->
        <organization>
          <name>DeliveryName</name>  <!--наименование грузополучателя-->
          <inn>DeliveryInn(10)</inn>  <!--ИНН грузополучателя-->
          <kpp>DeliveryKpp</kpp>  <!--КПП грузополучателя-->
        </organization>
        <russianAddress>  <!--российский адрес-->
          <regionISOCode>RegionCode</regionISOCode>
          <district>district</district>
          <city>City</city>
          <settlement>Village</settlement>
          <street>Street</street>
          <house>House</house>
          <flat>Flat</flat>
          <postalCode>>PostalCode</postalCode>
        </russianAddress>
        <additionalInfo>
          <phone>TelephoneNumber</phone> <!--телефон контактного лица-->
          <fax>FaxNumber</fax>   <!--факс контактного лица-->
          <bankAccountNumber>BankAccountNumber</bankAccountNumber>
          <bankName>BankName</bankName>
          <BIK>BankId</BIK>
          <nameOfCEO>ChiefName</nameOfCEO>   <!--ФИО руководителя-->
        </additionalInfo>
      </shipTo>
	  <ultimateCustomer>
        <gln>UltimateCustomerGln</gln>  <!--gln конечной точки доставки-->
        <organization>
          <name>UltimateCustomerName</name>  <!--наименование конечной точки доставки-->
          <inn>UltimateCustomerInn(10)</inn>  <!--ИНН конечной точки доставки-->
          <kpp>UltimateCustomerKpp</kpp>  <!--КПП конечной точки доставки-->
        </organization>
        <russianAddress>  <!--российский адрес-->
          <regionISOCode>RegionCode</regionISOCode>
          <district>district</district>
          <city>City</city>
          <settlement>Village</settlement>
          <street>Street</street>
          <house>House</house>
          <flat>Flat</flat>
          <postalCode>>PostalCode</postalCode>
        </russianAddress>
        <additionalInfo>
          <phone>TelephoneNumber</phone> <!--телефон контактного лица-->
          <fax>FaxNumber</fax>   <!--факс контактного лица-->
          <bankAccountNumber>BankAccountNumber</bankAccountNumber>
          <bankName>BankName</bankName>
          <BIK>BankId</BIK>
          <nameOfCEO>ChiefName</nameOfCEO>   <!--ФИО руководителя-->
        </additionalInfo>
      </ultimateCustomer>
      <transportation>
        <vehicleArrivalDateTime>deliveryDateForVehicleT00:00:00.000Z</vehicleArrivalDateTime> <!--информация о временных окнах для приемки машины покупателем. Каждое новое временное окно - в отлельном сегменте "transportation"-->
      </transportation>
      <transportBy>TransportBy</transportBy>  <!--кто доставляет и перевозит товары-->
    </deliveryInfo>
    <!-- конец блока данных о грузоотправителе и грузополучателе -->
*/

/*SELECT TOP 1 @part_ID = R.strqt_part_ID_Out
FROM KonturEDI.dbo.edi_Messages M
JOIN tp_StoreRequests           R ON R.strqt_ID = M.doc_ID
--JOIN tp_StoreRequestItems       I ON I.strqti_strqt_ID = M.doc_ID
WHERE M.messageId = @messageId*/

SET @DeliveryInfoXML = 
(
	SELECT 
	     @requestedDeliveryDateTime N'requestedDeliveryDateTime'
/*	 	 dbo.f_MultiLanguageStringToStringByLanguage1(part_Description, 25) N'gln' --gln поставщика
		,dbo.f_MultiLanguageStringToStringByLanguage1(part_Name, 25) N'organization/name' --наименование поставщика для ЮЛ	
		,dbo.f_MultiLanguageStringToStringByLanguage1(firm_INN, 25) N'organization/inn' --ИНН поставщика для ЮЛ
		,dbo.f_MultiLanguageStringToStringByLanguage1(firm_KPP, 25) N'organization/kpp' --КПП поставщика только для ЮЛ
		--российский адрес
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_RegionCode, 25) N'russianAddress/regionISOCode'
    	,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Area, 25) N'russianAddress/district'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_City, 25) N'russianAddress/city'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Village, 25) N'russianAddress/settlement'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Street, 25) N'russianAddress/street'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_House, 25) N'russianAddress/house'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Apartment, 25) N'russianAddress/flat'
        ,dbo.f_MultiLanguageStringToStringByLanguage1(addr_PostCode, 25) N'russianAddress/postalCode'
		-- Контактная информация
        ,dbo.f_MultiLanguageStringToStringByLanguage1(ISNULL(PD.pepl_PhoneWork, ''), 25) N'contactlInfo/CEO/orderContact'--телефон контактного лица
        ,dbo.f_MultiLanguageStringToStringByLanguage1(ISNULL(PD.pepl_PhoneCell, ''), 25) N'contactlInfo/CEO/fax'--факс контактного лица
        ,dbo.f_MultiLanguageStringToStringByLanguage1(ISNULL(PD.pepl_EMail, ''), 25) N'contactlInfo/CEO/email'--email контактного лица
       
*/		
	FROM tp_Partners       P
	LEFT JOIN tp_Firms     F ON F.firm_ID = P.part_firm_ID
	LEFT JOIN tp_Addresses A ON A.addr_obj_ID = F.firm_ID AND addr_Type = 2 -- CASE WHEN T2.part_firm_ID IS NULL THEN 3 ELSE 2 END AdddrType  -- рабочий (ФЛ) или юридический (ЮЛ) адрес
	LEFT JOIN tp_People PD ON PD.pepl_ID = F.firm_pepl_ID_Director
	WHERE part_ID = @part_ID
	FOR XML PATH(N'deliveryInfo'), TYPE
)

