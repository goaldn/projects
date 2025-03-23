
declare @currMonday int, @Abend int
	set @currMonday = 
		(select DateId from dwh.dbo.Dates
		where WeekOfYear = (select WeekOfYear from dwh.dbo.Dates where DateId = convert(varchar, getdate(), 112))
		and Year = (select left(convert(varchar, getdate(), 112)/100-1,4) ) and Weekday_ru= 'Понедельник')

	set @Abend = 
		(select DateId from dwh.dbo.Dates
		where WeekOfYear = (select WeekOfYear from dwh.dbo.Dates where DateId = convert(varchar, getdate(), 112))-1
		and Year = (select left(convert(varchar, getdate(), 112)/100-1,4) ) and Weekday_ru= 'Воскресенье')
		
		--select * from dwh.dbo.Dates where DateId = convert(varchar, getdate(), 112)
		

--================================= формат магазина

drop table if exists #format --(затронуто строк: 2405)
select a.siteId SD, n.SiteExtID as 'SiteBK', a.AttributeCode as 'SFCode',f.SiteFormat,a.SiteId as 'SiteId_dwh'
into #format
       from dwh.gld.SiteAttributes a
       join dwh.buf.Shops n on n.SiteID = a.SiteId 	   --join [DWH].[dbo].[DNodes] dn on dn.SiteId=n.SiteID
	   left join (values ('D','DIXY'),('G','UC'),('DS','DarkStore'),('T','TOWER')) as f(Code, SiteFormat) on f.Code = a.AttributeCode
       where 1=1
	   and @currMonday between a.StartDate and a.EndDate        --and CONVERT(varchar,getdate(),112) between a.StartDate and a.EndDate
       and a.AttributeClass = 'FORMAT'
	   --select * from #format2
	   --АО "ДИКСИ ЮГ"

--================================== РЦ по магазинам
drop table if exists #warehouse --(затронуто строк: 2403)
select a.siteId SD, '70' + left(AttributeValue,3) 'wh_code', wh.warehousename 
into #warehouse
from dwh.gld.siteattributes a with(nolock)
left join dwh.gld.warehouses wh with(nolock)  on warehouseextid = '70' + left(AttributeValue,3) 
where 1=1 and a.attributeClass = 'wh' 
and @currMonday between a.StartDate and a.EndDate --and (convert(nvarchar, getdate(), 112) ) between a.StartDate and a.EndDate
 --select * from #warehouse

--===================================== Справочник товара

drop table if exists #AM --(затронуто строк: 13 043 729)
select d.ItemId 'ItemId_DWH', a.PlngDescription, 'Am' 'Status', mp.SiteId 'SiteId_DWH', a.PlngSize,mp.DateFrom,mp.DateTo,PlngExtId
into #AM
FROM [DWH].[GLD].[TypeSettingMatrixPeriod]  mp
	JOIN [DWH].[GLD].[Attributes] a on mp.AttributeID = a.AttributeId
	JOIN [DWH].[dbo].[DProducts] d on mp.ItemId = d.ItemId
	JOIN [DWH].[dbo].[DNodes] s on mp.SiteId = s.SiteID
	WHERE 1=1 	and @currMonday between mp.DateFrom and mp.DateTo
	--select top 10 * from #AM 
	
drop table if exists #Prod --(затронуто строк: 305 318)
select i.*, i.ItemId as ItemIdPres, dp.ItemId as ItemIdDwh, dp.AssortTypeName
into #Prod
from Presentation.dim.Items i
join dwh.dbo.DProducts dp on dp.ItemExtid = i.ItemDixExtId
where   1=1
-- select * from #Prod


--======================================== ОБЩАЯ ИНФО ПО МАГАЗИНА ,ТОЛЬКО ОТКРЫТЫЕ + ФОРМАТ + РЦ

drop table if exists #shops_info --(затронуто строк: 2386)
select sh.SiteId 'SiteId_DWH',sh.SiteExtId,  f2.SiteFormat 'format' , sh.level6_descr 'shopsize', s.SiteId 'SiteId_Pres'
--,sh.level5_descr 'terr', sh.level4_descr 'obl',
,w.WarehouseName 'РЦ', sh.level3_descr 'fo'-- ,sh.ClosedDate
into #shops_info
from dwh.dbo.DNodes sh with(nolock) 
join Presentation.dim.Sites s with(nolock)  on s.SiteDixExtId = sh.SiteExtId  --and s.Type='Магазин'
left join #format f2 on f2.SiteId_dwh=sh.SiteId
left join #warehouse w on w.SD = sh.SiteId 
where s.Company = 'Дикси'
and (sh.ClosedDate is NULL or cast(sh.ClosedDate as int) > @currMonday)

--select * from #shops_info where ClosedDate is not NULL  @currMonday


--======================  все магазины с планограммами
		
Drop table if exists #all_shops_with_plng --(затронуто строк: 195742)
SELECT  a.SiteId 'SD', 	[DWH].[staging].[Planogramms].Decription 'Plng',
		RIGHT(a.AttributeValue, LEN(a.AttributeValue) - CHARINDEX('.', a.AttributeValue)) AS 'КЛАСТЕР+РАЗМЕР',
		SUBSTRING(a.AttributeValue, CHARINDEX('.', a.AttributeValue) + 1,1) AS 'КЛАСТЕР',
		SUBSTRING(a.AttributeValue, CHARINDEX('.', a.AttributeValue) + 2,LEN(a.AttributeValue)-CHARINDEX('.',a.AttributeValue)-1) AS 'РАЗМЕР',
		a.AttributeCode 'NumPlng'
INTO #all_shops_with_plng
FROM [DWH].[GLD].[SiteAttributes] a
JOIN [DWH].[staging].[Planogramms] on [DWH].[staging].[Planogramms].PlanogrammExtId = a.AttributeCode
	--FROM [DWH].[GLD].[TypeSettingMatrixPeriod] mp with (nolock)
	--JOIN [DWH].[GLD].[Attributes] a on mp.AttributeID = a.AttributeId
	where a.AttributeClass = 'PLNG' and @currMonday between StartDate and EndDate
	--select * from #all_shops_with_plng


----=====================  объединяем таблицы #all_shops_with_plng и #shops
drop table if exists #data --(затронуто строк: 194 161)
	select p.SD, sh.SiteExtId, sh.format,sh.shopsize, sh.РЦ, sh.fo, p.Plng, p.NumPlng, p.[КЛАСТЕР+РАЗМЕР], p.КЛАСТЕР, p.РАЗМЕР
	into #data
	FROM #all_shops_with_plng p
	INNER JOIN #shops_info sh on p.SD = sh.SiteId_DWH

--select * from #data


--================== КВОТЫ КВОТЫ КВОТЫ
drop table if exists #data1_with_quotas

select dt.*
, cast(isnull(qd_reg.AttributeValue,0) as int) 'РЕГ. КВОТА'
, cast(isnull(qd_in.AttributeValue,0) AS int)  'ИНАУТ КВОТА'
, isnull(cast(isnull(qd_reg.AttributeValue,0) as int) + cast(isnull(qd_in.AttributeValue,0) AS int),0) 'ОБЩАЯ КВОТА' --cast(isnull(qt.QTA_RG,0) as int) 'РЕГ. КВОТА', cast(isnull(qt.QTA_IN,0) AS int)  'ИНАУТ КВОТА', cast(isnull(qt.QTA_TOTAL,0) as int) 'ОБЩАЯ КВОТА'
into #data1_with_quotas
from #data dt
left join (select * 
			from [DWH].[GLD].[ItemAttributes_Quota_data] 
			where @currMonday between StartDate and EndDate AND AttributeClass ='QTA_RG') qd_reg on dt.NumPlng = qd_reg.PlngExtId AND dt.РАЗМЕР =  qd_reg.PlngSize
left join (select * 
			from [DWH].[GLD].[ItemAttributes_Quota_data] 
			where @currMonday between StartDate and EndDate AND AttributeClass ='QTA_IN') qd_in on dt.NumPlng = qd_in.PlngExtId AND dt.РАЗМЕР =  qd_in.PlngSize
--left join [DWH].[GLD].[ItemAttributes_Quota_today] qt on dt.NumPlng = qt.PlngExtId AND dt.Plng = qt.PlngName AND dt.РАЗМЕР =  qt.PlngSize

--select * from #data1_with_quotas

--====================================Наполнения

drop table if exists #fulls --(затронуто строк: 318990)
	SELECT s.SiteExtID ,s.level6_descr  , PlngDescription , PlngSize , s.level3_descr,d.AssortTypeName, a.InOut
	,iif( (d.AssortTypeName != 'In-Out' and not (a.InOut in ('Временный') and d.AssortTypeName in ('РЕГУЛЯРНЫЙ')) ), count(d.ItemName) , 0) 'rr'	-- 'Кол-во скю РЕГ+СЕЗ'
	,iif( d. AssortTypeName = 'In-Out', count(d.ItemName) , 0) 'ina'		--'Кол-во скю ИНАУТ'		
	,iif( ((a.InOut in ('Временный') and d.AssortTypeName in ('РЕГУЛЯРНЫЙ')) ), count(d.ItemName) , 0)  'ras'	--'Кол-во скю ПРОМО РАСШИР'	
into #fulls
	FROM [DWH].[GLD].[TypeSettingMatrixPeriod]  mp
	JOIN [DWH].[GLD].[Attributes] a on mp.AttributeID = a.AttributeId
	JOIN [DWH].[dbo].[DProducts] d on mp.ItemId = d.ItemId
	JOIN [DWH].[dbo].[DNodes] s on mp.SiteId = s.SiteId
	WHERE 1=1 	and @currMonday between mp.DateFrom and mp.DateTo 
	group by s.SiteExtID,s.level6_descr,  PlngDescription, PlngSize, d.AssortTypeName, a.InOut, s.level3_descr
	--select * from #fulls  where PlngDescription='СПЕЦ ОБОР' and SiteExtID=77109   

drop table if exists #full --(затронуто строк: 183618)
	SELECT distinct SiteExtID 'Магазин',level6_descr 'Формат' , PlngDescription 'Планограмма', PlngSize 'Размерность', level3_descr
	,sum(rr) 'Кол-во скю РЕГ+СЕЗ', sum(ina) 'Кол-во скю ИНАУТ'	, sum(ras)  'Кол-во скю ПРОМО РАСШИР'	
into #full
	from #fulls group by SiteExtID ,level6_descr  , PlngDescription , PlngSize , level3_descr
	--select * from #full where [Планограмма]='ВОДА' and Магазин=77109  



drop table if exists #blocks --(затронуто строк: 135988)
	select s.SiteId_DWH, PlngDescription,PlngSize, count(distinct p.ItemIdDwh) 'Count_sku' --count (ItemId)
into #blocks
	from Reps.pbi.OOS_Blocks bl
	join #Prod p on bl.ItemId=p.ItemIdPres
	join #shops_info s on s.SiteId_Pres=bl.SiteId
	join #AM am on am.ItemId_DWH=p.ItemIdDwh and am.SiteId_DWH=s.SiteId_DWH 
	where DateId = @currMonday-1
	group by s.SiteId_DWH,PlngSize,PlngDescription--, p.ItemIdDwh

	--select * from #blocks
	--select top(100) * from #blocks
	--d.ItemId 'ItemId_DWH', a.PlngDescription, 'Am' 'Status', mp.SiteId 'SiteId_DWH', a.PlngSize
	--23015	681
	--23418	530

--									

	--===============================================out

drop table if exists #out
	select  CAST(CAST(@currMonday AS VARCHAR(8)) AS date ) as 'Дата'  --@currMonday
	,d.SiteExtId 'БЮ' 
	,d.format 'Формат'
	,d.shopsize 'Типоразмер'
	,d.РЦ 'РЦ'
	,d.fo 'ФО'
	,d.Plng 'Планограмма'
	--Категория	КАТ ДИР	РТН
	,d.NumPlng 'Номер ПЛНГ'
	,d.[КЛАСТЕР+РАЗМЕР] 'Размерность'
	,d.КЛАСТЕР
	,d.РАЗМЕР
	,d.[РЕГ. КВОТА]
	,d.[ИНАУТ КВОТА]
	,d.[ОБЩАЯ КВОТА]

	,isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0) as 'Кол-во скю РЕГ+СЕЗ'
	,isnull(cast(f.[Кол-во скю ИНАУТ] as int),0) as 'Кол-во скю ИНАУТ'
	,isnull(cast(f.[Кол-во скю ПРОМО РАСШИР] as int),0) as 'Кол-во скю ПРОМО РАСШИР'
	,isnull(cast(bl.Count_sku as int),0) as 'Кол-во sku AM в блоке'
    ,case when isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0) = 0 THEN 'без наполнения'
	 else 'с наполнением' END 'Наполнение ПЛНГ'
	 ,d.[РЕГ. КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0) 'Рег. отклонение'
	 ,d.[ИНАУТ КВОТА] - isnull(cast(f.[Кол-во скю ИНАУТ] as int),0) as 'Инаут отклонение'
	 ,d.[ОБЩАЯ КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)-isnull(cast(f.[Кол-во скю ИНАУТ] as int),0) as 'Общее отклонение'
	 ,d.[ОБЩАЯ КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)-isnull(cast(f.[Кол-во скю ИНАУТ] as int),0)-isnull(cast(f.[Кол-во скю ПРОМО РАСШИР] as int),0) 'Общ. откл-е с учетом промо расш'
	 ,iif((d.[ОБЩАЯ КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)-isnull(cast(f.[Кол-во скю ИНАУТ] as int),0)) >= 0 and (d.[ОБЩАЯ КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)-isnull(cast(f.[Кол-во скю ИНАУТ] as int),0)-isnull(cast(f.[Кол-во скю ПРОМО РАСШИР] as int),0)) <0, 'создает переквоту','нет') 'Промо расш. создает переквоту'
	 ,IIF((d.[РЕГ. КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)) < 0,d.[РЕГ. КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0), '') as 'Рег отклонение (только минус)'
	 ,IIF((d.[ИНАУТ КВОТА] - isnull(cast(f.[Кол-во скю ИНАУТ] as int),0)) < 0,d.[ИНАУТ КВОТА] - isnull(cast(f.[Кол-во скю ИНАУТ] as int),0), '') as 'ИНАУТ отклонение (только минус)'
	 ,IIF((d.[ОБЩАЯ КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)-isnull(cast(f.[Кол-во скю ИНАУТ] as int),0)) < 0,d.[ОБЩАЯ КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)-isnull(cast(f.[Кол-во скю ИНАУТ] as int),0), '') as 'ОБЩ. отклонение (только минус)'
	 ,IIF((d.[ОБЩАЯ КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)-isnull(cast(f.[Кол-во скю ИНАУТ] as int),0)-isnull(cast(f.[Кол-во скю ПРОМО РАСШИР] as int),0)) < 0,d.[ОБЩАЯ КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)-isnull(cast(f.[Кол-во скю ИНАУТ] as int),0)-isnull(cast(f.[Кол-во скю ПРОМО РАСШИР] as int),0), '') as 'ОБЩ. отклонение с промо расш. (только минус)'
	 ,IIF((d.[РЕГ. КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)) < 0,1, 0) as 'Дефицит рег (1-есть, 0 - нет)'
	 ,IIF((d.[ИНАУТ КВОТА] - isnull(cast(f.[Кол-во скю ИНАУТ] as int),0)) < 0,1, 0) as 'Дефицит инаут (1-есть, 0 - нет)'
	 ,IIF((d.[ОБЩАЯ КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)-isnull(cast(f.[Кол-во скю ИНАУТ] as int),0)) < 0,1, 0) as 'ОБЩ. дефицит (1-есть, 0 -нет)'
	 ,IIF((d.[ОБЩАЯ КВОТА] - isnull(cast(f.[Кол-во скю РЕГ+СЕЗ] as int),0)-isnull(cast(f.[Кол-во скю ИНАУТ] as int),0)-isnull(cast(f.[Кол-во скю ПРОМО РАСШИР] as int),0)) < 0, 1, 0) as 'дефицит ОБЩ с учетом промо расшир(1-есть, 0 -нет)'




	
	
	--dq.*
	--, isnull(cast(r.[Кол-во скю РЕГ+СЕЗ] as int),0) as 'Кол-во скю РЕГ+СЕЗ' , isnull(cast(i.[Кол-во скю ИНАУТ] as int),0) as 'Кол-во скю ИНАУТ', isnull(cast(pr.[Кол-во скю ПРОМО РАСШИР] as int),0) as 'Кол-во скю ПРОМО РАСШИР',
	--	isnull(cast(bs.[Кол-во SKU АМ в блоке] as int),0) as 'Кол-во sku AM в блоке',
	--	case when isnull(cast(r.[Кол-во скю РЕГ+СЕЗ] as int),0) = 0 THEN 'без наполнения'
	--	else 'с наполнением' END 'Наполнение ПЛНГ'
into #out
	from #data1_with_quotas d 
	left join #full f on  f.Магазин=d.SiteExtId and f.Планограмма=d.Plng and d.[КЛАСТЕР+РАЗМЕР]=f.Размерность
	left join #blocks bl on bl.SiteId_DWH = d.SD and bl.PlngSize = d.[КЛАСТЕР+РАЗМЕР] and bl.PlngDescription = d.Plng

select * from #out

--#data1_with_quotas dq
--left join reg r on dq.SiteExtId =r.Магазин AND dq.Plng = r.Планограмма AND dq.КЛАСТЕР+РАЗМЕР= r.Размерность
--left join inout i on dq.SiteExtId =i.Магазин AND dq.Plng = i.Планограмма AND dq.КЛАСТЕР+РАЗМЕР= i.Размерность
--left join promo_rasshir pr on dq.SiteExtId =pr.Магазин AND dq.Plng = pr.Планограмма AND dq.КЛАСТЕР+РАЗМЕР= pr.Размерность
--left join blocked_sku bs on dq.SiteExtId =bs.Магазин AND dq.Plng = bs.Планограмма AND dq.КЛАСТЕР+РАЗМЕР= bs.Размерность


