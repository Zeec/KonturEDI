/*EXEC tpsrv_logon 'sv', '1'

-- GLN
DELETE FROM NoteTypes where nttp_ID = '74d6e928-475b-4f4c-8bc7-c216def422d6'
DELETE FROM NoteTypeObjects where nttpo_nttp_ID = '74d6e928-475b-4f4c-8bc7-c216def422d6'

INSERT INTO tp_NoteTypes ([nttp_ID],[nttp_vdt_ID],[nttp_del_ID],[nttp_Name],[nttp_Description],[nttp_ValueType],[nttp_Caption],[nttp_PageCaption],[nttp_Order],[nttp_IsUnique],[nttp_IsRequired],[nttp_IsDisabled])
VALUES('74d6e928-475b-4f4c-8bc7-c216def422d6', 0, NULL, 'GLN', 'GLN', NULL, 'GLN', 'EDIKontur', 1, 1, 0, 0)

INSERT INTO tp_NoteTypeObjects (nttpo_ID, nttpo_nttp_ID, nttpo_tpsyso_ID, nttpo_TableName)
VALUES('00ec63e0-9b9b-3b4d-a868-fc098cc5adf2', '74d6e928-475b-4f4c-8bc7-c216def422d6', '7601db3d-30b0-498d-a00a-202e5ed2b28e', NULL)
--
*/

/*
INSERT INTO [tp_NoteType]([nttp_ID],[nttp_vdt_ID],[nttp_del_ID],[nttp_Name],[nttp_Description],[nttp_ValueType],[nttp_Caption],[nttp_PageCaption],[nttp_Order],[nttp_IsUnique],[nttp_IsRequired],[nttp_IsDisabled])
VALUES(CAST ('74d6e928-475b-4f4c-8bc7-c216def422d6' as uniqueidentifier),0,NULL,'GLN','GLN',NULL,'GLN','EDIKontur',1,1,0,0)

INSERT INTO [tp_NoteTypeObjects]([nttpo_ID],[nttpo_nttp_ID],[nttpo_tpsyso_ID],[nttpo_TableName])
VALUES(CAST ('00ec63e0-9b9b-3b4d-a868-fc098cc5adf2' as uniqueidentifier),CAST ('74d6e928-475b-4f4c-8bc7-c216def422d6' as uniqueidentifier),CAST ('7601db3d-30b0-498d-a00a-202e5ed2b28e' as uniqueidentifier),NULL)

INSERT INTO [tp_NoteTypes]([nttp_ID],[nttp_vdt_ID],[nttp_del_ID],[nttp_Name],[nttp_Description],[nttp_ValueType],[nttp_Caption],[nttp_PageCaption],[nttp_Order],[nttp_IsUnique],[nttp_IsRequired],[nttp_IsDisabled])
VALUES(CAST ('515b41b0-838a-5146-ac5a-2f52314097b7' as uniqueidentifier),0,NULL,'GTIN','GTIN',NULL,'GTIN','EDIKontur',64,1,0,0)


INSERT INTO [tp_NoteTypeObjects]([nttpo_ID],[nttpo_nttp_ID],[nttpo_tpsyso_ID],[nttpo_TableName])
VALUES(CAST ('4fc5fbe0-5772-3246-b64d-a347278117d0' as uniqueidentifier),CAST ('515b41b0-838a-5146-ac5a-2f52314097b7' as uniqueidentifier),CAST ('fb320583-33dd-4fa4-a195-13134b517fa0' as uniqueidentifier),NULL)

INSERT INTO [tp_NoteTypes]([nttp_ID],[nttp_vdt_ID],[nttp_del_ID],[nttp_Name],[nttp_Description],[nttp_ValueType],[nttp_Caption],[nttp_PageCaption],[nttp_Order],[nttp_IsUnique],[nttp_IsRequired],[nttp_IsDisabled])
VALUES(CAST ('fc9f6de1-3cf3-5247-ae66-8efc7b40c5b8' as uniqueidentifier),0,NULL,'Статус EDIKontur','Статус EDIKontur',NULL,'Статус EDIKontur','EDIKontur',66,1,0,0)
-------------------
INSERT INTO tp_NoteTypeObjects ([nttpo_ID],[nttpo_nttp_ID],[nttpo_tpsyso_ID],[nttpo_TableName])
VALUES(CAST ('74577b99-d874-c145-a13f-52a8e44addb7' as uniqueidentifier),CAST ('fc9f6de1-3cf3-5247-ae66-8efc7b40c5b8' as uniqueidentifier),CAST ('fb5d0433-aeb2-d143-b93c-cc91779430b1' as uniqueidentifier),NULL)

INSERT INTO [tp_NoteTypes]([nttp_ID],[nttp_vdt_ID],[nttp_del_ID],[nttp_Name],[nttp_Description],[nttp_ValueType],[nttp_Caption],[nttp_PageCaption],[nttp_Order],[nttp_IsUnique],[nttp_IsRequired],[nttp_IsDisabled])
VALUES(CAST ('35d20336-935e-b042-b0f7-7d5fdf032ab2' as uniqueidentifier),0,NULL,'Единица измерения EDIKontur','Единица измерения EDIKontur',NULL,'Единица измерения EDIKontur','EDIKontur',202,1,0,0)
-------------------
INSERT INTO tp_NoteTypeObjects([nttpo_ID],[nttpo_nttp_ID],[nttpo_tpsyso_ID],[nttpo_TableName])
VALUES(CAST ('f476e11f-7d19-824d-a3c0-889c17b1880b' as uniqueidentifier),CAST ('35d20336-935e-b042-b0f7-7d5fdf032ab2' as uniqueidentifier),CAST ('b7138994-e03b-4e10-99ad-57d18c6220d1' as uniqueidentifier),NULL)
*/