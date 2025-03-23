
declare @currMonday int, @Abend int
	set @currMonday = 
		(select DateId from dwh.dbo.Dates
		where WeekOfYear = (select WeekOfYear from dwh.dbo.Dates where DateId = convert(varchar, getdate(), 112))
		and Year = (select left(convert(varchar, getdate(), 112)/100-1,4) ) and Weekday_ru= '�����������')

	set @Abend = 
		(select DateId from dwh.dbo.Dates
		where WeekOfYear = (select WeekOfYear from dwh.dbo.Dates where DateId = convert(varchar, getdate(), 112))-1
		and Year = (select left(convert(varchar, getdate(), 112)/100-1,4) ) and Weekday_ru= '�����������')
		
		--select * from dwh.dbo.Dates where DateId = convert(varchar, getdate(), 112)
		

--================================= ������ ��������

drop table if exists #format --(��������� �����: 2405)
select a.siteId SD, n.SiteExtID as 'SiteBK', a.AttributeCode as 'SFCode',f.SiteFormat,a.SiteId as 'SiteId_dwh'
into #format
       from dwh.gld.SiteAttributes a
       join dwh.buf.Shops n on n.SiteID = a.SiteId 	   --join [DWH].[dbo].[DNodes] dn on dn.SiteId=n.SiteID
	   left join (values ('D','DIXY'),('G','UC'),('DS','DarkStore'),('T','TOWER')) as f(Code, SiteFormat) on f.Code = a.AttributeCode
       where 1=1
	   and @currMonday between a.StartDate and a.EndDate        --and CONVERT(varchar,getdate(),112) between a.StartDate and a.EndDate
       and a.AttributeClass = 'FORMAT'
	   --select * from #format2
	   --�� "����� ��"

--================================== �� �� ���������
drop table if exists #warehouse --(��������� �����: 2403)
select a.siteId SD, '70' + left(AttributeValue,3) 'wh_code', wh.warehousename 
into #warehouse
from dwh.gld.siteattributes a with(nolock)
left join dwh.gld.warehouses wh with(nolock)  on warehouseextid = '70' + left(AttributeValue,3) 
where 1=1 and a.attributeClass = 'wh' 
and @currMonday between a.StartDate and a.EndDate --and (convert(nvarchar, getdate(), 112) ) between a.StartDate and a.EndDate
 --select * from #warehouse

--===================================== ���������� ������

drop table if exists #AM --(��������� �����: 13 043 729)
select d.ItemId 'ItemId_DWH', a.PlngDescription, 'Am' 'Status', mp.SiteId 'SiteId_DWH', a.PlngSize,mp.DateFrom,mp.DateTo,PlngExtId
into #AM
FROM [DWH].[GLD].[TypeSettingMatrixPeriod]  mp
	JOIN [DWH].[GLD].[Attributes] a on mp.AttributeID = a.AttributeId
	JOIN [DWH].[dbo].[DProducts] d on mp.ItemId = d.ItemId
	JOIN [DWH].[dbo].[DNodes] s on mp.SiteId = s.SiteID
	WHERE 1=1 	and @currMonday between mp.DateFrom and mp.DateTo
	--select top 10 * from #AM 
	
drop table if exists #Prod --(��������� �����: 305 318)
select i.*, i.ItemId as ItemIdPres, dp.ItemId as ItemIdDwh, dp.AssortTypeName
into #Prod
from Presentation.dim.Items i
join dwh.dbo.DProducts dp on dp.ItemExtid = i.ItemDixExtId
where   1=1
-- select * from #Prod


--======================================== ����� ���� �� �������� ,������ �������� + ������ + ��

drop table if exists #shops_info --(��������� �����: 2386)
select sh.SiteId 'SiteId_DWH',sh.SiteExtId,  f2.SiteFormat 'format' , sh.level6_descr 'shopsize', s.SiteId 'SiteId_Pres'
--,sh.level5_descr 'terr', sh.level4_descr 'obl',
,w.WarehouseName '��', sh.level3_descr 'fo'-- ,sh.ClosedDate
into #shops_info
from dwh.dbo.DNodes sh with(nolock) 
join Presentation.dim.Sites s with(nolock)  on s.SiteDixExtId = sh.SiteExtId  --and s.Type='�������'
left join #format f2 on f2.SiteId_dwh=sh.SiteId
left join #warehouse w on w.SD = sh.SiteId 
where s.Company = '�����'
and (sh.ClosedDate is NULL or cast(sh.ClosedDate as int) > @currMonday)

--select * from #shops_info where ClosedDate is not NULL  @currMonday


--======================  ��� �������� � �������������
		
Drop table if exists #all_shops_with_plng --(��������� �����: 195742)
SELECT  a.SiteId 'SD', 	[DWH].[staging].[Planogramms].Decription 'Plng',
		RIGHT(a.AttributeValue, LEN(a.AttributeValue) - CHARINDEX('.', a.AttributeValue)) AS '�������+������',
		SUBSTRING(a.AttributeValue, CHARINDEX('.', a.AttributeValue) + 1,1) AS '�������',
		SUBSTRING(a.AttributeValue, CHARINDEX('.', a.AttributeValue) + 2,LEN(a.AttributeValue)-CHARINDEX('.',a.AttributeValue)-1) AS '������',
		a.AttributeCode 'NumPlng'
INTO #all_shops_with_plng
FROM [DWH].[GLD].[SiteAttributes] a
JOIN [DWH].[staging].[Planogramms] on [DWH].[staging].[Planogramms].PlanogrammExtId = a.AttributeCode
	--FROM [DWH].[GLD].[TypeSettingMatrixPeriod] mp with (nolock)
	--JOIN [DWH].[GLD].[Attributes] a on mp.AttributeID = a.AttributeId
	where a.AttributeClass = 'PLNG' and @currMonday between StartDate and EndDate
	--select * from #all_shops_with_plng


----=====================  ���������� ������� #all_shops_with_plng � #shops
drop table if exists #data --(��������� �����: 194 161)
	select p.SD, sh.SiteExtId, sh.format,sh.shopsize, sh.��, sh.fo, p.Plng, p.NumPlng, p.[�������+������], p.�������, p.������
	into #data
	FROM #all_shops_with_plng p
	INNER JOIN #shops_info sh on p.SD = sh.SiteId_DWH

--select * from #data


--================== ����� ����� �����
drop table if exists #data1_with_quotas

select dt.*
, cast(isnull(qd_reg.AttributeValue,0) as int) '���. �����'
, cast(isnull(qd_in.AttributeValue,0) AS int)  '����� �����'
, isnull(cast(isnull(qd_reg.AttributeValue,0) as int) + cast(isnull(qd_in.AttributeValue,0) AS int),0) '����� �����' --cast(isnull(qt.QTA_RG,0) as int) '���. �����', cast(isnull(qt.QTA_IN,0) AS int)  '����� �����', cast(isnull(qt.QTA_TOTAL,0) as int) '����� �����'
into #data1_with_quotas
from #data dt
left join (select * 
			from [DWH].[GLD].[ItemAttributes_Quota_data] 
			where @currMonday between StartDate and EndDate AND AttributeClass ='QTA_RG') qd_reg on dt.NumPlng = qd_reg.PlngExtId AND dt.������ =  qd_reg.PlngSize
left join (select * 
			from [DWH].[GLD].[ItemAttributes_Quota_data] 
			where @currMonday between StartDate and EndDate AND AttributeClass ='QTA_IN') qd_in on dt.NumPlng = qd_in.PlngExtId AND dt.������ =  qd_in.PlngSize
--left join [DWH].[GLD].[ItemAttributes_Quota_today] qt on dt.NumPlng = qt.PlngExtId AND dt.Plng = qt.PlngName AND dt.������ =  qt.PlngSize

--select * from #data1_with_quotas

--====================================����������

drop table if exists #fulls --(��������� �����: 318990)
	SELECT s.SiteExtID ,s.level6_descr  , PlngDescription , PlngSize , s.level3_descr,d.AssortTypeName, a.InOut
	,iif( (d.AssortTypeName != 'In-Out' and not (a.InOut in ('���������') and d.AssortTypeName in ('����������')) ), count(d.ItemName) , 0) 'rr'	-- '���-�� ��� ���+���'
	,iif( d. AssortTypeName = 'In-Out', count(d.ItemName) , 0) 'ina'		--'���-�� ��� �����'		
	,iif( ((a.InOut in ('���������') and d.AssortTypeName in ('����������')) ), count(d.ItemName) , 0)  'ras'	--'���-�� ��� ����� ������'	
into #fulls
	FROM [DWH].[GLD].[TypeSettingMatrixPeriod]  mp
	JOIN [DWH].[GLD].[Attributes] a on mp.AttributeID = a.AttributeId
	JOIN [DWH].[dbo].[DProducts] d on mp.ItemId = d.ItemId
	JOIN [DWH].[dbo].[DNodes] s on mp.SiteId = s.SiteId
	WHERE 1=1 	and @currMonday between mp.DateFrom and mp.DateTo 
	group by s.SiteExtID,s.level6_descr,  PlngDescription, PlngSize, d.AssortTypeName, a.InOut, s.level3_descr
	--select * from #fulls  where PlngDescription='���� ����' and SiteExtID=77109   

drop table if exists #full --(��������� �����: 183618)
	SELECT distinct SiteExtID '�������',level6_descr '������' , PlngDescription '�����������', PlngSize '�����������', level3_descr
	,sum(rr) '���-�� ��� ���+���', sum(ina) '���-�� ��� �����'	, sum(ras)  '���-�� ��� ����� ������'	
into #full
	from #fulls group by SiteExtID ,level6_descr  , PlngDescription , PlngSize , level3_descr
	--select * from #full where [�����������]='����' and �������=77109  



drop table if exists #blocks --(��������� �����: 135988)
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
	select  CAST(CAST(@currMonday AS VARCHAR(8)) AS date ) as '����'  --@currMonday
	,d.SiteExtId '��' 
	,d.format '������'
	,d.shopsize '����������'
	,d.�� '��'
	,d.fo '��'
	,d.Plng '�����������'
	--���������	��� ���	���
	,d.NumPlng '����� ����'
	,d.[�������+������] '�����������'
	,d.�������
	,d.������
	,d.[���. �����]
	,d.[����� �����]
	,d.[����� �����]

	,isnull(cast(f.[���-�� ��� ���+���] as int),0) as '���-�� ��� ���+���'
	,isnull(cast(f.[���-�� ��� �����] as int),0) as '���-�� ��� �����'
	,isnull(cast(f.[���-�� ��� ����� ������] as int),0) as '���-�� ��� ����� ������'
	,isnull(cast(bl.Count_sku as int),0) as '���-�� sku AM � �����'
    ,case when isnull(cast(f.[���-�� ��� ���+���] as int),0) = 0 THEN '��� ����������'
	 else '� �����������' END '���������� ����'
	 ,d.[���. �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0) '���. ����������'
	 ,d.[����� �����] - isnull(cast(f.[���-�� ��� �����] as int),0) as '����� ����������'
	 ,d.[����� �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)-isnull(cast(f.[���-�� ��� �����] as int),0) as '����� ����������'
	 ,d.[����� �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)-isnull(cast(f.[���-�� ��� �����] as int),0)-isnull(cast(f.[���-�� ��� ����� ������] as int),0) '���. ����-� � ������ ����� ����'
	 ,iif((d.[����� �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)-isnull(cast(f.[���-�� ��� �����] as int),0)) >= 0 and (d.[����� �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)-isnull(cast(f.[���-�� ��� �����] as int),0)-isnull(cast(f.[���-�� ��� ����� ������] as int),0)) <0, '������� ���������','���') '����� ����. ������� ���������'
	 ,IIF((d.[���. �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)) < 0,d.[���. �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0), '') as '��� ���������� (������ �����)'
	 ,IIF((d.[����� �����] - isnull(cast(f.[���-�� ��� �����] as int),0)) < 0,d.[����� �����] - isnull(cast(f.[���-�� ��� �����] as int),0), '') as '����� ���������� (������ �����)'
	 ,IIF((d.[����� �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)-isnull(cast(f.[���-�� ��� �����] as int),0)) < 0,d.[����� �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)-isnull(cast(f.[���-�� ��� �����] as int),0), '') as '���. ���������� (������ �����)'
	 ,IIF((d.[����� �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)-isnull(cast(f.[���-�� ��� �����] as int),0)-isnull(cast(f.[���-�� ��� ����� ������] as int),0)) < 0,d.[����� �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)-isnull(cast(f.[���-�� ��� �����] as int),0)-isnull(cast(f.[���-�� ��� ����� ������] as int),0), '') as '���. ���������� � ����� ����. (������ �����)'
	 ,IIF((d.[���. �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)) < 0,1, 0) as '������� ��� (1-����, 0 - ���)'
	 ,IIF((d.[����� �����] - isnull(cast(f.[���-�� ��� �����] as int),0)) < 0,1, 0) as '������� ����� (1-����, 0 - ���)'
	 ,IIF((d.[����� �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)-isnull(cast(f.[���-�� ��� �����] as int),0)) < 0,1, 0) as '���. ������� (1-����, 0 -���)'
	 ,IIF((d.[����� �����] - isnull(cast(f.[���-�� ��� ���+���] as int),0)-isnull(cast(f.[���-�� ��� �����] as int),0)-isnull(cast(f.[���-�� ��� ����� ������] as int),0)) < 0, 1, 0) as '������� ��� � ������ ����� ������(1-����, 0 -���)'




	
	
	--dq.*
	--, isnull(cast(r.[���-�� ��� ���+���] as int),0) as '���-�� ��� ���+���' , isnull(cast(i.[���-�� ��� �����] as int),0) as '���-�� ��� �����', isnull(cast(pr.[���-�� ��� ����� ������] as int),0) as '���-�� ��� ����� ������',
	--	isnull(cast(bs.[���-�� SKU �� � �����] as int),0) as '���-�� sku AM � �����',
	--	case when isnull(cast(r.[���-�� ��� ���+���] as int),0) = 0 THEN '��� ����������'
	--	else '� �����������' END '���������� ����'
into #out
	from #data1_with_quotas d 
	left join #full f on  f.�������=d.SiteExtId and f.�����������=d.Plng and d.[�������+������]=f.�����������
	left join #blocks bl on bl.SiteId_DWH = d.SD and bl.PlngSize = d.[�������+������] and bl.PlngDescription = d.Plng

select * from #out

--#data1_with_quotas dq
--left join reg r on dq.SiteExtId =r.������� AND dq.Plng = r.����������� AND dq.�������+������= r.�����������
--left join inout i on dq.SiteExtId =i.������� AND dq.Plng = i.����������� AND dq.�������+������= i.�����������
--left join promo_rasshir pr on dq.SiteExtId =pr.������� AND dq.Plng = pr.����������� AND dq.�������+������= pr.�����������
--left join blocked_sku bs on dq.SiteExtId =bs.������� AND dq.Plng = bs.����������� AND dq.�������+������= bs.�����������


