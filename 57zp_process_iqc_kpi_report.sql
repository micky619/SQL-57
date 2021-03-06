--/****** Object:  StoredProcedure [dbo].[zp_process_iqc_kpi_report]    Script Date: 08/11/2017 11:40:07 AM ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--ALTER PROC [dbo].[zp_process_iqc_kpi_report] (@FromTime DateTime = NULL,@ToTime DateTime = NULL)
--as
----[ 0.REQUEST RECORD ]-----------------------------------------------------------------------          
---- 2014/05/07 RyanLiu create for aps review facility      
-----------------------------------------------------------------------------------------------           
--/*  -- Update by Jill at 2017-07-31 for mingdong_zhu request (MR201707-116Y)
--DECLARE @FromTime DateTime ,@ToTime DateTime
--select @FromTime= '2016-01-01 00:00:00.000',@ToTime = '2017-07-01 00:00:00.000'
--EXEC [zp_process_iqc_kpi_report] @FromTime,@ToTime

----exec joyDB.dbo.zp_process_iqc_kpi_report  '2016-01-01 00:00:00.000','2017-07-01 00:00:00.000'
--*/
          
----[ 1.UPDATE SEQUENCE ]----------------------------------------------------------------------
-- --/*         

SET NOCOUNT ON

DECLARE @FromTime DateTime, @ToTime DateTime               --57
SELECT @FromTime = '2016-11-29' , @ToTime = '2016-11-30'
          
DECLARE @ERROR_MSG  VARCHAR(2000),@XML_MSG XML ,@PROCNAME VARCHAR(100)          
DECLARE @ERROR_PROC VARCHAR(1000) ,@PROCLEVEL INT ,@ERROR_SEVERITY INT,@RTN_STATUS INT          
DECLARE @XML_OUTPUT XML         
DECLARE @id_admcomp int          
         
SELECT  @PROCLEVEL      = @@NESTLEVEL          
SELECT  @PROCNAME       = isnull( OBJECT_NAME(@@PROCID) ,'' )          
SELECT  @ERROR_PROC     = ''          
SELECT  @ERROR_MSG      = ''          
SELECT  @ERROR_SEVERITY = 0          
SELECT  @RTN_STATUS     = 0          
SELECT  @XML_OUTPUT     = ''           
SELECT  @XML_MSG        = ''          
         
SET XACT_ABORT ON           
          
BEGIN TRY
--if object_id('ReportDB.dbo.sp_exec_analysis') is NULL
--create table ReportDB.dbo.sp_exec_analysis (dt_run datetime,sp_name nvarchar(150),loginname nvarchar(60),hostname nvarchar(60))


--insert ReportDB.dbo.sp_exec_analysis (dt_run,sp_name,loginname,hostname)
--SELECT getdate(),'zp_process_iqc_kpi_report',loginame,hostname
--FROM master.dbo.sysprocesses WHERE spid = @@spid
   
--DECLARE @FromTime DateTime
--DECLARE @ToTime DateTime
	--Set @FromTime=convert(varchar(10),dateadd(day,-35,DATEADD(wk,DATEDIFF(wk,0,getdate()),-1)),111)
	--Set @ToTime=convert(varchar(10),dateadd(day,-1,DATEADD(wk,DATEDIFF(wk,0,getdate()),-1)),111)



SELECT @id_admcomp = id_admcomp FROM admcomp where stat_void = 0 AND stat_isheadquarter = 1
	IF @FromTime IS NULL
 BEGIN
	   Set @FromTime=convert(varchar(10),dateadd(day,-35,DATEADD(wk,DATEDIFF(wk,0,getdate()),-1)),111)
	   Set @ToTime=convert(varchar(10),dateadd(day,-1,DATEADD(wk,DATEDIFF(wk,0,getdate()),-1)),111)
	 --Set @FromTime= convert(varchar(10),'2015-07-21 00:00:00.000',111)
	 --Set @ToTime= convert(varchar(10),'2015-07-22 00:00:00.000',111)

END

IF object_id('tempdb.dbo.#tt') is not null drop table #tt                     
IF object_id('tempdb.dbo.#result') is not null drop table #result

  SELECT iqc_master.id_iqcmaster
         ,iqc_detail.id_iqcdetail
         ,reason_descrip = convert(nvarchar(120),iqc_reject_reason.reason_descrip)        
    INTO #tt        
    FROM iqc_master
        ,iqc_detail
        ,iqc_reject_reason        
   WHERE iqc_detail.id_iqcmaster = iqc_master.id_iqcmaster        
     and iqc_detail.reason_code = iqc_reject_reason.id_iqcreason        
     and iqc_master.qty_inspect = iqc_master.qty_reject
     and convert(char(10),iqc_master.dt_inspect,111) between @FromTime and @ToTime        
ORDER BY iqc_master.id_iqcmaster        
        
-- SELECT 'table'='#tt', * from   #tt			/*用來打印出前面這一段執行了什麼*/

SELECT distinct week=DATENAME(Week,receive.dt_received)
	  ,received_month = right(convert(varchar(6),receive.dt_received,112),2)			/*MR201707-116Y 2017/08/16 明冬:『自動計算出Month』*/ --add by micky
	--,receive.status_receive
	  ,delivery_no= convert(nvarchar(100),receive_invoice.delivery_no)
	--,receive_invoice.receive_no
	  ,receive.receive_no
	  ,expect_receive.source_no
	  ,parnter = convert(nvarchar(25),case when receive.source_code in ('PO','RV','CS','PX') OR receive.receive_type = 2 then vendor.vendor_alias else oecust_br.br_name end)
	--,bond_mark
	  ,comp.part_no
	--,sale.model_no																		/*MR201707-116Y 2017/08/16 明冬:『model_no 拿掉』*/ --add by micky
	  ,descrip=convert(nvarchar(60),comp.descrip)
	  ,material_type='          '					  --new
    --,received.currency
	--,received.up
	--,received.up_inv
	  ,receive.dt_received
	--,dt_inspect=iqc_master.dt_inspect
	  ,dt_inspect=isnull(iqc_master.dt_inspect,'')
	  ,receive.dt_process
	  ,duration_hour_iqc=isnull(round(DATEDIFF(hh ,receive.dt_received,iqc_master.dt_inspect),2),'')
	  ,duration_hour_stock=round(DATEDIFF(hh ,receive.dt_received,receive.dt_process),2)
	--,invoice_no = case when isnull(received.id_apinv,0) >0 then 
--(select distinct apinv.inv_no from apinv apinv with(nolock) where received.id_apinv=apinv.id_apinv and apinv.stat_void=0)
--else 
--case when isnull (received.invoice_no,'') = '' then receive_invoice.invoice_no else isnull (received.invoice_no,'')  end --add by chiaan at 2012-05-22
--end,
--invoice_no = case when isnull (received.invoice_no,'') = '' then receive_invoice.invoice_no else isnull (received.invoice_no,'')  end ,--mark by chiaan at 2010-05-22
	  ,room_name=convert(nvarchar(50),stock.room_name)
	  ,received.quantity
	  ,qty_sample=iqc_master.qty_sample
	  ,received.qty_pass
	  ,received.qty_iqc
	  ,received.qty_reject
	  ,inspect_result= convert(nvarchar(20),isnull(iqc_result.descrip,''))
	  ,reject_reason=convert(nvarchar(120),isnull(iqc_reason.reason_descrip,''))
	  ,receive.source_code
	--,received.loc_iqc
	--,defective_type=''
	--,receive_invoice.delivery_no
	--,location = icidf_location.location
	  ,receiver = convert(nvarchar(40),rtrim(admuser.user_id + ' ' + admuser.user_name))
	  ,receive_side=case when substring(admuser.user_id,1,1)='J' then 'JoyTech'
					else  'Accton' end
	  ,inspect_by=isnull(iqc_master.inspect_by,'')
	  ,inspect_side=case when substring(inspect_by,1,1)='J' then 'JoyTech'
					else 'Accton' end
	--,iccrm_no = isnull(received.iccrm_no,'')
	--,date_code = iqc_master.date_code
	--,lot_no = iqc_master.lot_no
	--,receive.dt_arrival
	--,receive.carrier
	--,receive.shipvia
	--,receive.tracking_ref_no
	--,received.custom_apply_no
	--,received.currency_inv
	--,vendor.vendor_no
	--,sale.weight
/*popo.trade_type,*/
	--,vendor.trade_type		 /*add by joyce at 2011/02/11*/
	--,term_of_condition = (SELECT 			max(  oem_icim_comp.term_of_condition )
--							FROM oem_icim_comp    oem_icim_comp
--								,icim_sale icim_sale
--							WHERE oem_icim_comp.id_icim_comp = comp.id_icim_comp
--							  AND oem_icim_comp.id_icim_comp = icim_sale.id_icim_comp
--							  AND oem_icim_comp.stat_void = 0 and
--							  AND comp.stat_void = 0)
--								 .icim_property.stat_license
--								 ,glvh.vou_no, /*add by joyce at 2011/04/19*/
	  ,shipper_name = convert(nvarchar(20),isnull(receive_invoice.shipper_name, isnull(expect_receive.shipper_name,''))) /* add by amy at 2011/11/29*/
	--,dt_inspect = iqc_master.dt_inspect
	--,received.id_icim_comp
    --,receive_invoice.id_vendor AS id_business_partner
    --,icim_vendor.iqc_type
      ,iqc_type_desc = convert(nvarchar(20),isnull(dbo.fn_iqc_type_desc('',icim_vendor.iqc_type,'IM'),''))
    --,popod.stat_up_special
	--,expect_received.id_expect_received		  /*add by muriel at 2013/03/22*/
	--,icim_property.inq_type5					  /*MR201306-048A 2013/06/13*/
	  ,icim_property.mgr_category				  /*MR201306-048A 2013/06/13*/
	--,icim_property.mtl_code					  /*MR201306-048A 2013/06/13*/
INTO #result
FROM ((((((((((((((((expect_received	expect_received with (nolock)
				join expect_receive	expect_receive with (nolock)
				  on expect_received.id_expect_receive = expect_receive.id_expect_receive
				 and expect_receive.stat_void = 0
				 and expect_received.stat_void = 0
				 and expect_receive.id_admcomp = @id_admcomp)
			   --and expect_receive.source_code like :arg_source_code		--ALL
			   --and expect_receive.source_no like :arg_source_no)			--ALL

			     join received	received with (nolock)
				  on received.id_expect_received = expect_received.id_expect_received
				 and received.stat_void = 0)

				 join receive	receive with (nolock)
				   on receive.id_receive = received.id_receive
				  and receive.stat_void = 0
				--and (receive.dt_received >= '2013-09-22 00:00:00' and receive.dt_received <= '2013-10-06 23:59:59')) join
				  and (convert(char(10),receive.dt_received,111) between @FromTime and @ToTime))

				 join receive_invoice   receive_invoice with (nolock)
				   on receive_invoice.id_receive_invoice = receive.id_receive_invoice
				  and receive_invoice.stat_void = 0)
 
				 join icim_comp	comp with (nolock)
				   on received.id_icim_comp = comp.id_icim_comp)
				--and comp.part_no between :arg_partno_from and :arg_partno_to)			--ALL

				 join icim_sale	sale with (nolock)
				   on sale.id_icim_comp = comp.id_icim_comp)

				 join icim_property 	icim_property with (nolock)
				   on sale.id_icim_comp = icim_property.id_icim_comp)
  
				 join icstockroom	stock with (nolock)
				   on received.id_icstkroom = stock.id_icstockroom)

			 left join popo	popo with (nolock)
					on popo.id_popo=expect_receive.source_id)
  
			 left join popod popod with(nolock)
					on popo.id_popo=popod.id_popo
				   and expect_received.source_id = popod.id_popod and expect_received.id_expect_received = popod.id_expect_received and popod.stat_void = 0)	--add at 2013-05-30 

			 left join vendor	vendor with (nolock)
			    	on receive.id_business_partner = vendor.id_vendor)
	   
			 left join oecust_br		oecust_br with (nolock)
					on receive.id_business_partner = oecust_br.id_oecust_br)
	   
			 left join icidf_location	icidf_location with (nolock)
					on comp.id_icim_comp = icidf_location.id_icim_comp
				   and received.id_icstkroom = icidf_location.id_icstockroom)

			 left join admuser	admuser with (nolock)
					on receive.id_receiver = admuser.id_admuser)
	   
			 left join iqc_master	iqc_master with (nolock)
					on receive.receive_no = iqc_master.ref_no)

			 left join icim_vendor	icim_vendor						-- add by charlie.ssu 2012/11/05   
					on icim_vendor.id_icim_comp = received.id_icim_comp       
				   and icim_vendor.id_vendor = receive_invoice.id_vendor)

		left join apinv on received.id_apinv = apinv.id_apinv					/*add by joyce at 2011/04/19*/
		left join glvh on apinv.id_glvh = glvh.id_glvh							/*add by joyce at 2011/04/19*/
		left join codetable iqc_result with (nolock) on id_iqc_result = iqc_result.id_codetable and iqc_result.stat_void=0
		left join #tt iqc_reason with (nolock) on iqc_master.id_iqcmaster=iqc_reason.id_iqcmaster

--select 'table'='#result1',* from   #result			/*打印*/

UPDATE a set a.material_type='CM'
  FROM #result a
 WHERE substring(part_no,3,1)='M'



IF @id_admcomp=10
BEGIN
	  UPDATE #result
	     SET #result.material_type=b.part_type
	    FROM workTemp.dbo.iqc_kpi_report_type b
	   WHERE substring(#result.part_no,1,3)=b.prefix
	     AND len(substring(#result.part_no,1,3))=len(b.prefix)

	  UPDATE #result
	     SET #result.material_type=b.part_type
	    FROM workTemp.dbo.iqc_kpi_report_type b
	   WHERE substring(#result.part_no,1,4)=b.prefix
	     AND len(substring(#result.part_no,1,4))=len(b.prefix)

	  UPDATE #result
	     SET #result.material_type=b.part_type
    	FROM workTemp.dbo.iqc_kpi_report_type b
       WHERE len(isnull(#result.material_type,''))=0
	     AND substring(#result.part_no,1,2)<>b.prefix
	     AND len(substring(#result.part_no,1,2))=len(b.prefix)
END



IF object_id('tempdb.dbo.#result1') is not null drop table #result1  

SELECT received_month AS Month,week,delivery_no,receive_no,parnter,part_no,descrip,material_type=convert(nvarchar(10),material_type),dt_received,dt_inspect,dt_process,duration_hour_iqc,duration_hour_stock,room_name,quantity=sum(quantity),qty_sample,qty_pass=sum(qty_pass),qty_iqc,qty_reject=sum(qty_reject),inspect_result,reject_reason,source_code,receiver,receive_side,inspect_by,inspect_side,shipper_name,iqc_type_desc,mgr_category
INTO #result1                    
FROM #result
GROUP BY received_month,week,delivery_no,receive_no,parnter,part_no,descrip,material_type,dt_received,dt_inspect,dt_process,duration_hour_iqc,duration_hour_stock,room_name,qty_sample,qty_iqc,inspect_result,reject_reason,source_code,receiver,receive_side,inspect_by,inspect_side,shipper_name,iqc_type_desc,mgr_category



SELECT * 
FROM #result1			/*最終select*/



/*
SELECT Month,week,delivery_no,receive_no,parnter,part_no,descrip,material_type=convert(nvarchar(10),material_type),dt_received,dt_inspect,dt_process,duration_hour_iqc,duration_hour_stock,room_name,quantity,qty_sample,qty_pass,qty_iqc,qty_reject,inspect_result,reject_reason,source_code,receiver,receive_side,inspect_by,inspect_side,shipper_name,iqc_type_desc,mgr_category
                    
FROM #result
WHERE receive_no='RF1701002J_1'
*/
      

      
END TRY          
          
BEGIN CATCH          
     
	 select 'ENTER CATCＨ'     
 SELECT @ERROR_SEVERITY = ERROR_SEVERITY()          
 SELECT @ERROR_PROC     = ERROR_PROCEDURE()           
          
        
               
 SELECT @RTN_STATUS = CASE WHEN ERROR_STATE() >= 101  AND ERROR_STATE() <= 200  THEN  ltrim(str(ERROR_STATE())) ELSE 201 END              
 SELECT @ERROR_MSG  = 'PROC['+LTRIM(STR(@PROCLEVEL))+']:' + @PROCNAME +' [LINE]:'+ CONVERT(VARCHAR(MAX),ERROR_LINE()) + ', ' + ERROR_MESSAGE()                
          
  
  SELECT @ERROR_MSG 
        
 IF  (XACT_STATE()) = -1          
  BEGIN          
   ROLLBACK TRAN           
  END           
          
 IF  (XACT_STATE()) = 1          
  BEGIN          
   COMMIT TRANSACTION           
  END           
          
   
          
 Goto Exception          
          
END CATCH          
          
ProcEnd:          
     
	   
SELECT @XML_OUTPUT = CAST ( '<outputstring>'          
         + CAST ( @XML_OUTPUT AS NVARCHAR(MAX) )          
         +    '<rtncode>'          
         +       '<code>' + LTRIM(str(@RTN_STATUS)) + '</code>'          
         +       '<msg>'  + @ERROR_MSG  + '</msg>'              
         +    '</rtncode>'          
         +'</outputstring>' AS XML )          
          
RETURN --@RTN_STATUS          
          
Exception:          
       

SELECT @XML_OUTPUT = CAST ( '<outputstring>'          
         + CAST ( @XML_OUTPUT AS NVARCHAR(MAX) )          
         +    '<rtncode>'          
         +       '<code>' + LTRIM(str(@RTN_STATUS)) + '</code>'          
         +       '<msg>'  + @ERROR_MSG  + '</msg>'              
         +    '</rtncode>'          
         +'</outputstring>' AS XML )   
		         
SELECT @XML_OUTPUT 
	              
RETURN --@RTN_STATUS                  
          
RAISERROR ('(PROC:[%d]%s CODE:%d %s)', @ERROR_SEVERITY,@RTN_STATUS, @PROCLEVEL ,@ERROR_PROC , @RTN_STATUS ,@ERROR_MSG )  
 
 
 --*/