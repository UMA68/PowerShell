IF EXISTS ( SELECT * FROM sys.objects WHERE name = 'STP_GetTime' AND user_name(schema_id) =  'dbo' )
 DROP PROC STP_GetTime
GO

-- ストアド名を定義する
CREATE PROCEDURE STP_GetTime
AS
BEGIN
    -- 時間を取得する
    DECLARE @time DATETIME
    SET @time = GETDATE()
    -- 時間を返す
    SELECT @time AS CurrentTime
END
GO