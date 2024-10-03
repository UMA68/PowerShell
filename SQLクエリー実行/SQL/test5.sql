--テスト
--ﾃｽﾄ
SELECT * FROM TESTTABLE WHERE
(TableNameId = 6)

DELETE FROM TESTTABLE WHERE
(TableNameId = 6)

INSERT INTO TESTTABLE (TableNameId,Column1,Column2) VALUES (6,N'Ｓｈｉｆ－ＪＩＳ',N'シフトジスｼﾌﾄｼﾞｽ')

SELECT * FROM TESTTABLE WHERE
(TableNameId = 6)

