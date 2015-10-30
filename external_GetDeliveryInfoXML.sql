IF OBJECT_ID(N'external_GetDeliveryInfoXML', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.external_GetDeliveryInfoXML
GO

CREATE PROCEDURE dbo.external_GetDeliveryInfoXML  (
    @part_ID_From UNIQUEIDENTIFIER,
	@addr_ID_From UNIQUEIDENTIFIER,
    @part_ID_To UNIQUEIDENTIFIER,
	@addr_ID_To UNIQUEIDENTIFIER,
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
		 CONVERT(NVARCHAR(MAX), @requestedDeliveryDateTime, 127) N'requestedDeliveryDateTime'
		,(SELECT 
	 		-- dbo.f_MultiLanguageStringToStringByLanguage1(part_Description, 25) N'gln' --gln грузоотправителя
  	 	    CONVERT(NVARCHAR(MAX), note_Value) N'gln' --gln поставщика
		FROM tp_Partners        P
		--LEFT JOIN tp_Firms      F ON F.firm_ID = P.part_firm_ID
		--LEFT JOIN tp_Addresses  A ON A.addr_obj_ID = F.firm_ID AND addr_Type = 2 -- CASE WHEN T2.part_firm_ID IS NULL THEN 3 ELSE 2 END AdddrType  -- рабочий (ФЛ) или юридический (ЮЛ) адрес
		--LEFT JOIN tp_People    PD ON PD.pepl_ID = F.firm_pepl_ID_Director
		LEFT JOIN tp_Notes      N ON N.note_obj_ID = P.part_ID AND N.note_nttp_ID = '74D6E928-475B-4F4C-8BC7-C216DEF422D6'
		WHERE part_ID = @part_ID_From
		FOR XML PATH(N'shipFrom'), TYPE)
		,(SELECT
			 -- dbo.f_MultiLanguageStringToStringByLanguage1(part_Description, 25) N'gln' --gln грузоотправителя
			 CONVERT(NVARCHAR(MAX), note_Value) N'gln'
			--российский адрес
			,(SELECT
				 dbo.f_MultiLanguageStringToStringByLanguage1(addr_RegionCode, 25) N'regionISOCode'
    			,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Area, 25) N'district'
				,dbo.f_MultiLanguageStringToStringByLanguage1(addr_City, 25) N'city'
				,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Village, 25) N'settlement'
				,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Street, 25) N'street'
				,dbo.f_MultiLanguageStringToStringByLanguage1(addr_House, 25) N'house'
				,dbo.f_MultiLanguageStringToStringByLanguage1(addr_Apartment, 25) N'flat'
				,dbo.f_MultiLanguageStringToStringByLanguage1(addr_PostCode, 25) N'postalCode'
			FROM tp_Addresses
			WHERE addr_ID = @addr_ID_To
			FOR XML PATH(N'russianAddress'), TYPE)
     	FROM tp_Partners        P
		LEFT JOIN tp_Firms      F ON F.firm_ID = P.part_firm_ID
		LEFT JOIN tp_Notes      N ON N.note_obj_ID = P.part_ID AND N.note_nttp_ID = '74D6E928-475B-4F4C-8BC7-C216DEF422D6'
		WHERE part_ID = @part_ID_To
		FOR XML PATH(N'shipTo'), TYPE			
		)
	FOR XML PATH(N'deliveryInfo'), TYPE
)

