
--======================================================== Квоты по дням
drop table if exists #dates_q		
	;with d as
		(select *, d.Year*100+Month 'MonthId', d.YearForWeek*100+WeekOfYear 'WeekId', d.YearForWeek*10000+WeekOfYear*100+DayOfWeek 'DayOfWeekId' 
		from dwh.dbo.dates d)	
	select * into #dates_q
	from d	where 1=1 and DateId between cast((convert(nvarchar, getdate(), 112) ) as int) and cast( (convert(varchar, getdate()+180, 112)) as int) 
--select * from #dates_q


drop table if exists #qotes	
select 
	 DateId, WeekOfYear
	,p.Decription as 'Plng'
	,p.[PlanogrammExtId] as 'NumPlng' 
	,SiteFormat 'SiteFormat'
	,cast(PlngSize as nvarchar(max)) as 'Size'	
	,QTA_RG	,QTA_IN
into #qotes	
from 
	(select PlngExtId, SiteFormat, PlngSize, AttributeClass, AttributeValue ,d.DateId, d.WeekOfYear
	from dwh.gld.ItemAttributes_Quota_data	
	join #dates_q d on d.DateId between StartDate and EndDate) a
pivot(sum(AttributeValue) 
	for AttributeClass in([QTA_RG],[QTA_IN]) ) pvt
	left join dwh.staging.Planogramms p on p.PlanogrammExtId = pvt.PlngExtId	
--select * from #qotes where NumPlng=129


drop table if exists #QTA1 
select q.DateId, q.WeekOfYear,  q.Plng, q.SiteFormat,Size, CAST(QTA_IN AS INT) AS QTA_IN, 
		CASE
		WHEN Size IN (0,1,2,3,4,5,6,7,8,9,10,11,12) THEN 'D'
		WHEN Size in (50,20,21,22) THEN 'G'
		WHEN Size =77 THEN 'Darkstore'
		END AS FormatTest
into #QTA1
from #qotes q 
where QTA_IN is not NULL  and QTA_IN!=0
--select * from #QTA1 where Plng = 'КОСМЕТИКА'  order by 1,3

drop table if exists #QTA2
SELECT DateId, WeekOfYear, Plng, SiteFormat, Size, QTA_IN, FormatTest, 'T' AS ClusterTest  
into #QTA2
from #QTA1
WHERE FormatTest = 'D'
UNION ALL
SELECT DateId, WeekOfYear, Plng, SiteFormat, Size, QTA_IN, FormatTest, 'L' AS ClusterTest
from #QTA1
WHERE FormatTest = 'D'
UNION ALL
SELECT DateId, WeekOfYear, Plng, SiteFormat, Size, QTA_IN, FormatTest, 'M' AS ClusterTest
from #QTA1
WHERE FormatTest = 'D'
UNION ALL
SELECT DateId, WeekOfYear, Plng, SiteFormat, Size, QTA_IN, FormatTest, 'H' AS ClusterTest
from #QTA1
WHERE FormatTest = 'D'
UNION ALL
SELECT DateId, WeekOfYear, Plng, SiteFormat, Size, QTA_IN, FormatTest, 'DARKSTORE' AS ClusterTest
from #QTA1
WHERE FormatTest = 'Darkstore'
UNION ALL
SELECT DateId, WeekOfYear, Plng, SiteFormat, Size, QTA_IN, FormatTest, 'GO' AS ClusterTest
from #QTA1
WHERE FormatTest = 'G'


--select DISTINCT SIZE from #QTA2 where Plng = 'Косметика' order by 1,3

drop table if exists #QTA3 
SELECT DateId, WeekOfYear, Plng, SiteFormat, Size, QTA_IN, FormatTest, ClusterTest, 'ЦЕНТРАЛЬНЫЙ' AS FO
into #QTA3
from #QTA2

UNION ALL
SELECT DateId, WeekOfYear, Plng, SiteFormat, Size, QTA_IN, FormatTest, ClusterTest, 'СЕВЕРО-ЗАПАДНЫЙ' AS FO
from #QTA2

--select * from #QTA3



--======================================================== Добавляем Размерность
drop table if exists #shops
	SELECT *
    , case	when level6_descr in ('M','S','L','XL') then 'GO' 
			when level6_descr='TOWER' then 'TOWER' 
			when level6_descr='DARKSTORE' then 'DARKSTORE' 
			else 'DIXY' end 'SiteFormat' 
into #shops 
	FROM [DWH].[dbo].[DNodes]  --i on i.SiteID = n.SiteID
	WHERE 1=1 and LegalEntityName like 'АО "ДИКСИ ЮГ"' and [ClosedDate] is NULL and level2_descr='ДИКСИ'
--select * from #shops

drop table if exists #prod
	SELECT * into #prod
	FROM [DWH].[dbo].[DProducts]
	WHERE 1=1 and AssortTypeName in ('IN-OUT')
--select * from #prod
	
drop table if exists #sh
	SELECT  da.DateId, da.WeekOfYear, PlngDescription 'Plng'
		, s.SiteFormat, PlngSize 'Sizes', left(PlngSize,1) 'Claster'
		, SUBSTRING(PlngSize,2,6) 'Size',  s.level3_descr 'FO', count(distinct D.g_ItemCode) sum_sku
	into #sh
	FROM [DWH].[GLD].[TypeSettingMatrixPeriod] mp
		JOIN [DWH].[GLD].[Attributes] a on mp.AttributeID = a.AttributeId
		JOIN #prod d on mp.ItemId = d.ItemId
		JOIN #shops s on mp.SiteId = s.SiteID
		JOIN #dates_q da on da.DateId between mp.DateFrom and mp.DateTo
	WHERE 1=1 and InOut in ('Постоянный', 'Временный') 
	group by da.DateId, da.WeekOfYear, PlngDescription , s.SiteFormat, PlngSize , SUBSTRING(PlngSize,2,6),left(PlngSize,1), s.level3_descr
	--select * from #sh where 1=1 and Plng='КОСМЕТИКА' order by 1,3
	

drop table if exists #qwot 
	select  q.DateId, q.WeekOfYear,  q.Plng, s.SiteFormat,q.Size, q.QTA_IN, s.Claster,s.FO 'ФО' ,isnull(s.sum_sku,0) 'sum_sku'
into #qwot
	FROM #QTA1 q 
	left join #sh s on q.Size=s.Size and q.DateId=s.DateId and q.WeekOfYear=s.WeekOfYear and q.Plng=s.Plng and q.SiteFormat=s.SiteFormat 	
	where 1=1 
	--select * from #qwot where 1=1  and Plng='БЫТОВАЯ ХИМИЯ'  order by 1,3

drop table if exists #result
Select q3.DateId, q3.WeekOfYear, q3.Plng,q3.SiteFormat, q3.Size, q3.QTA_IN, q3.FormatTest, q3.ClusterTest, q3.FO, qw.sum_sku, (q3.QTA_IN - COALESCE(qw.sum_sku,0)) AS FreePlace
into #result
FROM #QTA3 q3
LEFT JOIN #qwot qw

ON q3.DateId = qw.DateId AND q3.WeekOfYear = qw.WeekOfYear AND q3.Plng = qw.Plng AND q3.Size = qw.Size and q3.ClusterTest = qw.Claster and q3.FO = qw.ФО 

drop table if exists #result2
Select DateId, WeekOfYear, Plng, 
case when	Size in (20,21,22) then 'GO' 
			when Size = 50 then 'TOWER' 
			when Size=77 then 'DARKSTORE' 
			else 'DIXY' end 'SiteFormat' 
, Size, QTA_IN, ClusterTest, Concat(#result.ClusterTest,#result.Size) 'Размерность' , isnull(sum_sku,0) 'Занято под InOut', FreePlace, 
case when FO = 'СЕВЕРО-ЗАПАДНЫЙ'then 'СЗФО'
	when FO = 'ЦЕНТРАЛЬНЫЙ'then 'ЦФО' end FO
into #result2
From #result
--select * from #result2 order by 1,3




select *
from #result2 order by 1,3
