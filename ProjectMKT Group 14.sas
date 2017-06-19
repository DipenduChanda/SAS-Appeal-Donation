/**********************************Start from scratch*****************************************/

PROC SQL;
SELECT count(*)as AppealTotal, Count(Distinct(donor_id))as NumberofDonorsTargetted 
FROM project.Appeals;
QUIT;

PROC SQL;
SELECT count(*)as DonationTotal, Count(Distinct(donor_id))as NumberofDonorsDonated 
FROM project.Donations;
QUIT;


PROC CONTENTS DATA=project.appeals; RUN;
PROC CONTENTS DATA=project.Donations; RUN;

/****Create donation with Zipcode****/
Proc sort data = project.Appeals; by donor_id appeal_id; run;

Proc sort data = project.Donations; by donor_id appeal_id; run;

/**File creation for Appeal with Zipcode: START**/
PROC SQL;
 CREATE TABLE Project.DistinctDonation as
 SELECT Distinct(donor_id), zipcode
 FROM project.Donations;
QUIT;
proc sort data = Project.DistinctDonation nodupkey;
by donor_id;
run;
PROC CONTENTS DATA=project.DistinctDonation; RUN;
PROC SQL;
SELECT count(*)as DonationTotal, Count(Distinct(donor_id))as NumberofDonorsDonated 
FROM project.DistinctDonation;
QUIT;


PROC SQL outobs = 1800000;
 CREATE TABLE project.appealsZip as
 SELECT a.donor_id,a.appeal_id,a.appeal_cost,a.appeal_date, zipcode
 FROM project.Appeals as a,project.DistinctDonation as b
 where a.donor_id = b.donor_id;
QUIT;
PROC SQL;
SELECT count(*)as Nullval 
FROM project.appealsZip
WHERE zipcode is Null;
QUIT; /**gives 0 value***/

PROC CONTENTS DATA=project.appeals; RUN;
PROC CONTENTS DATA=project.appealszip; RUN;

PROC Delete data = project.DistinctDonation;
run;
/**File creation for Appeal with Zipcode: ****END**/



/***Fixing Appeal ID***NOT working**/
data project.mappeals; set project.appealsZip (rename=(appeal_id = Oldappeal_id));
 Length appeal_id $100;
 appeal_id = input(Oldappeal_id, best15.);
 drop Oldappeal_id
Run;
PROC CONTENTS DATA=project.appeals; RUN;
PROC CONTENTS DATA=project.donations; RUN;
PROC Delete data = project.mappeals;
run;
/***************************/

/***************Appeals effectiveness on donation based on zipcode: top 100************************/
PROC SQL;
CREATE TABLE project.mzipappeal as
SELECT zipcode, COUNT(appeal_id) AS TOTALAPPEALS
FROM project.appealszip
GROUP BY zipcode;
QUIT;

PROC SQL outobs=100;
CREATE TABLE project.mTopZipappeals as
SELECT zipcode, TOTALAPPEALS
FROM project.mzipappeal
WHERE TOTALAPPEALS >=(SELECT 2*STD(TOTALAPPEALS) FROM project.mzipappeal)
ORDER BY TOTALAPPEALS DESC;
QUIT;


PROC SQL;
SELECT STD(TOTALAPPEALS) FROM project.appealsdata;
QUIT;


PROC SQL;
CREATE TABLE project.mzipdonation as
SELECT zipcode, COUNT(donor_id) AS TOTALDONORS
FROM project.donations
GROUP BY zipcode;
QUIT;

PROC SQL outobs=100;
CREATE TABLE project.mTopZipDonation as
SELECT zipcode, TOTALDONORS
FROM project.mzipdonation
WHERE TOTALDONORS >=(SELECT 2*STD(TOTALDONORS) FROM project.mzipdonation)
ORDER BY TOTALDONORS DESC;
QUIT;


PROC SQL;
CREATE TABLE project.topDonationAppeal as
SELECT b.zipcode, b.TOTALDONORS, a.TOTALAPPEALS
FROM project.mTopZipappeals as a, project.mTopZipDonation as b
WHERE a.zipcode = b.zipcode;
QUIT;

/*We are getting 70/100 match*/

/*************Corr between appeals and donation on customer***************/
PROC SQL;
CREATE TABLE project.mdonorcountdonations as
SELECT donor_id, COUNT(appeal_id) AS TOTALDonations
FROM project.donations
GROUP BY donor_id;
QUIT;

PROC SQL;
CREATE TABLE project.mdonorcountappeal as
SELECT donor_id, COUNT(appeal_id) AS TOTALAppeals
FROM project.appealszip
GROUP BY donor_id;
QUIT;

PROC SQL;
CREATE TABLE project.mdonorappeal as
SELECT a.donor_id, a.TOTALDonations, b.TOTALAppeals
FROM project.mdonorcountappeal as b, project.mdonorcountdonations as a
where a.donor_id = b.donor_id ;
QUIT;

Proc corr data = project.mdonorappeal; run;

/*********************************************************/

LIBNAME demogr 'C:\Users\dxc163830\Desktop\Project work-predictive\Project(1)\Ram';
LIBNAME project 'C:\Users\dxc163830\Desktop\Project work-predictive\Project(1)';

/**********************ineffective appeals**************************/
PROC SQL;
CREATE TABLE project.mineffAppeals as
SELECT a.*
FROM project.appealszip as a
where a.appeal_id NOT IN ( SELECT Distinct(appeal_id) FROM Project.donations) ;
QUIT;

			/**********************effective appeals**************************/
PROC SQL;
CREATE TABLE project.meffAppeals as
SELECT a.*
FROM project.appealszip as a
where a.appeal_id IN ( SELECT Distinct(appeal_id) FROM Project.donations) ;
QUIT;

			/********short sample of different donor in effective appeals***/
PROC SQL;
CREATE TABLE project.meffAppeals_diffdonor as
SELECT a.*
FROM project.meffAppeals as a
where a.donor_id IN ( SELECT Distinct(donor_id) FROM Project.mdonorcountdonations where TOTALDonations >= (SELECT 2*STD(TOTALDonations) FROM project.mdonorcountdonations)) ;
QUIT; /**gives 198262 records**/
PROC CONTENTS DATA=project.meffAppeals_diffdonor; RUN;

							/**********NOT WORKING
							proc sort data = Project.meffAppeals_diffdonor nodupkey;
							by donor_id;
							run;
							PROC CONTENTS DATA=project.meffAppeals_diffdonor; RUN;

/****************************************Simple Random Sampling****/
proc surveyselect data=project.meffAppeals_diffdonor
   method=srs n=134550 out=project.mSRSeffAppeals_diffdonor;
run;

/***********************combined set of effective and ineffective appeals for logistic analysis********************/
data project.m01appeals; set project.mSRSeffAppeals_diffdonor(in= A) project.mineffAppeals; 
if A then effAppeal = 1; else effAppeal = 0;
Run;

PROC CONTENTS DATA=project.m01appeals; RUN;
PROC Delete data = project.mSRSeffAppeals_diffdonor; run;

/*****************Demographic**************************/
PROC CONTENTS DATA= Demogr.Hhincomedistribution varnum; RUN;
PROC CONTENTS DATA=demogr.householdtype varnum; RUN;
PROC CONTENTS DATA=demogr.populationbyageandgender varnum; RUN;
PROC CONTENTS DATA=demogr.urbanruralhousingunits varnum; RUN;

proc contents data=Demogr.Hhincomedistribution out=mHhincomedistribution noprint;
run;


PROC SQL;
CREATE TABLE project.mDemographicNeeded as
SELECT a.zip, a.Total_Households, (a._60_000_to__99_999 + a._100_000_to__149_999 + a._150_000_to__199_999 + a._200_000_or_more) as IncomeAbv60, a.Median_HH_Income, a.Avg_HH_Income_for_HH_Income_less as AvgIncome,
 b.Total_Households_, b.Family_households_, b.Family_households___Married_coup as MarriedWithKid, b.Nonfamily_households_, 
 c.Total_population, c.Male___22___29_years+ c.Male___30___44_years as validMale2244, Female___23___29_years+ Female___30___44_years as Female2244,
 d.Total_Housing_Units, d.Urban, d.Semi_Urban, d.Rural____Nonfarm + d.Rural____Nonfarm as Rural
FROM Demogr.Hhincomedistribution as a, Demogr.householdtype as b, 
Demogr.populationbyageandgender as c, Demogr.urbanruralhousingunits as d
WHERE a.zip = b.zip and b.zip = c.zip and c.zip = d.zip;
QUIT;

PROC SQL;
CREATE TABLE project.mDemographicCleaned as
SELECT zip, Median_HH_Income, MarriedWithKid, Urban, Semi_Urban, Rural
FROM project.mDemographicNeeded;
QUIT;
/*************************************************/

/******************Analysis: m01appeals+ Demo****************************/
PROC SQL;
 CREATE TABLE project.m01appealswithDemo as
 SELECT a.*, b.*
FROM project.m01appeals as a left join project.mDemographicNeeded as b
 ON a.Zipcode = b.zip;
QUIT;

	/****Proc corr data = project.m01appealswithDemo; run;************simple Correlation******/

	/************Color coded Correlation******/
proc template;
   edit Base.Corr.StackedMatrix;
      column (RowName RowLabel) (Matrix) * (Matrix2);
      edit matrix;
         cellstyle _val_  = -1.00 as {backgroundcolor=CXEEEEEE},
                   _val_ <= -0.75 as {backgroundcolor=red},
                   _val_ <= -0.50 as {backgroundcolor=blue},
                   _val_ <= -0.25 as {backgroundcolor=cyan},
                   _val_ <=  0.25 as {backgroundcolor=white},
                   _val_ <=  0.50 as {backgroundcolor=cyan},
                   _val_ <=  0.75 as {backgroundcolor=blue},
                   _val_ <   1.00 as {backgroundcolor=red},
                   _val_  =  1.00 as {backgroundcolor=CXEEEEEE};
      end;
   end;
run;

ods _all_ close;
ods html body='corr.html' style=HTMLBlue;

proc corr data=project.m01appealswithDemo noprob; /* mDemographicNeeded m01appealswithDemo*/
var effAppeal zip Median_HH_Income MarriedWithKid Semi_Urban Rural;
   ods select PearsonCorr;
run;

ods html close;
ods listing;

proc template;
   delete Base.Corr.StackedMatrix;
run;
/*******************Color coded corelation ends*********************zip Total_Households IncomeAbv60 Median_HH_Income AvgIncome Total_Households_ Family_households_ MarriedWithKid Nonfamily_households_ Total_population validMale2244 Female2244 Total_Housing_Units Urban Semi_Urban Rural**/

/***Various models****/
title ’Linear Probability Model’;/*r2= 0.02!!*/
proc reg data = project.m01appealswithDemo plot= none;
 model effAppeal = zip Median_HH_Income MarriedWithKid Urban Semi_Urban Rural;
quit;

title ’Linear Probability Model - Robust Standard Errors’;/*r2= 0.02!!*/
proc reg data = project.m01appealswithDemo plot= none;
/***acov option tells SAS about robust regression****/
 model effAppeal = zip Median_HH_Income MarriedWithKid Urban Semi_Urban Rural / acov;
 output out = effappealreg pred = prob;
quit;

title ’Logit Model’;
proc logistic data = project.m01appealswithDemo plot= none;
   model effAppeal (event='1')= zip Median_HH_Income MarriedWithKid Urban Semi_Urban Rural ;
   output out = effappeallogit pred = prob;
run;

title ’Probit Model’;
proc logistic data = project.m01appealswithDemo plot= none;
   model effAppeal (event='1')= zip Median_HH_Income MarriedWithKid Urban Semi_Urban Rural / link = probit;
   output out = effappealprobit pred = prob;
run;

/* Conditional logit LEFT TO DO*****Proc mdc with type clogit*/
/*Poisson regression model Proc genmod****/
/*Tobit for censored data like age*/
/*Hectic ==Probit -> IMR-> OLS**/
/*Random and fixed effect model*/

LIBNAME piyush 'C:\Users\dxc163830\Desktop\Project work-predictive\Project(1)\Piyush';
Data project.rfm; set piyush.pre_rfm( rename=(day = recency freq= frequency)); keep donor_id recency frequency monetary; Run;


Proc sort data = project.rfm; by recency frequency monetary; Run; 
/*RFM*/
Proc rank data = project.rfm out = project.rfm_output groups = 2;
	var recency frequency monetary;
	ranks r f m;
run;

Proc sort data=project.rfm_output; by r f m; Run; 

/***rfm ranking***/
DATA project.rfm_output_rank;
set project.rfm_output;
if r = 0 and f = 1 and m = 1 then Market_cluster = 1;
if r = 0 and f = 0 and m = 1 then Market_cluster = 2;
if r = 0 and f = 1 and m = 0 then Market_cluster = 3;
if r = 0 and f = 0 and m = 0 then Market_cluster = 4;
if r = 1 and f = 1 and m = 1 then Market_cluster = 5;
if r = 1 and f = 0 and m = 1 then Market_cluster = 6;
if r = 1 and f = 1 and m = 0 then Market_cluster = 7;
if r = 1 and f = 0 and m = 0 then Market_cluster = 8;
run;

PROC SQL;
 CREATE TABLE project.RFM_OutputZip as
 SELECT a.*, b.Zipcode
FROM project.rfm_output_rank as a left join project.DistinctDonation as b
 ON a.donor_id = b.donor_id;
QUIT;

Proc contents data= project.rfm_output_rank; run;

Proc contents data= project.RFM_OutputZip; run;

PROC SQL;
 CREATE TABLE project.RFM_OutputDemogr as
 SELECT a.*, b.*
FROM project.rfm_outputZip as a inner join project.mDemographicNeeded as b
 ON a.Zipcode = b.zip;
QUIT;

Proc contents data= project.RFM_OutputDemogr; run;

/**************panel***********/
PROC SQL;
CREATE TABLE project.panelstudy as
SELECT a.*, b.Median_HH_Income,b.MarriedWithKid,b.Urban, b.Semi_Urban, b.Rural
FROM project.donations as a inner join project.mDemographicCleaned as b
on a.Zipcode = b.zip;
QUIT;

proc sort data=project.panelstudy; By gift_date donor_id; RUN;
Data project.panelstudy1;
set project.panelstudy;
year=year(gift_date);
run;

PROC SQL;
CREATE TABLE project.panelstudy as
SELECT a.*, b.Median_HH_Income,b.MarriedWithKid,b.Urban, b.Semi_Urban, b.Rural
FROM project.donations as a inner join project.mDemographicCleaned as b
on a.Zipcode = b.zip;
QUIT;

PROC SQL;
CREATE TABLE project.panelstudy2 as
SELECT a.*
FROM project.panelstudy1 as a 
Where a.donor_id IN ( SELECT Distinct(donor_id) FROM Project.panelstudy1 group by donor_id 
Having count(*) >= 3) ;
QUIT;

PROC SQL;
CREATE TABLE project.panelstudy111 as
SELECT Distinct(donor_id) FROM Project.panelstudy1 group by donor_id 
Having count(*) >= 2 ;
QUIT;

proc sort data=project.panelstudy2; By  gift_date donor_id; RUN;
proc panel data=project.panelstudy2 plot = none;
id donor_id gift_date;
model  gift_amount= Median_HH_Income MarriedWithKid Urban Semi_Urban Rural /fixone;




/********************************************************extra***********************************/
LIBNAME Project 'C:\Users\rss161030\Desktop\Files\Final Project\code';


proc reg data=project.zipcode_donations_train_hhincome;
	MODEL TotDonation = Avg_HH_Income Total_households;
run;

proc reg data=project.zipcode_donations_test_hhincome;
	MODEL TotDonation = Avg_HH_Income Total_households;
run;

PROC CORR DATA = Project.Urbanruraldata;
	VAR TotDonation Total_Housing_Units Urban Semi_urban Rural____Nonfarm Rural____farm;
RUN;
/*Train data regression code and results*/
PROC SQL;
CREATE TABLE Project.train_regression as	 
SELECT a.zipcode,a.Total_Households,a.Avg_HH_Income,a.TOTDONATION,b.Family_households_,b.Nonfamily_households____Househol,c.Total_Population,c.Male,c.female,d.Total_Housing_Units,d.urban,d.semi_urban
FROM Project.zipcode_donations_train_hhincome a, Project.householdtype b, Project.Populationbyageandgender c,Project.urbanruralhousingunits d
WHERE a.zipcode  = b.zip and a.zipcode  = c.zip and a.zipcode  = d.zip;
QUIT; 

proc reg data=project.train_regression;
	MODEL TOTDONATION = Avg_HH_Income  urban semi_urban;
run;

PROC CORR DATA = Project.train_regression;
	VAR Avg_HH_Income urban semi_urban;
RUN;

/**/
/*Test data regression code and results*/
PROC SQL;
CREATE TABLE Project.test_regression as	 
SELECT a.zipcode,a.Total_Households,a.Avg_HH_Income,a.TOTDONATION,b.Family_households_,b.Nonfamily_households____Househol,c.Total_Population,c.Male,c.female,d.Total_Housing_Units,d.urban,d.semi_urban
FROM Project.zipcode_donations_test_hhincome a, Project.householdtype b, Project.Populationbyageandgender c,Project.urbanruralhousingunits d
WHERE a.zipcode  = b.zip and a.zipcode  = c.zip and a.zipcode  = d.zip;
QUIT; 

proc reg data=project.test_regression;
	MODEL TOTDONATION = Avg_HH_Income  urban semi_urban;
run;

proc panel data=project.test_regression plots=none;
	MODEL TOTDONATION = Avg_HH_Income  urban semi_urban;
run;

PROC CORR DATA = Project.test_regression;
	VAR Avg_HH_Income urban semi_urban;
RUN;

/**/


/*Cust lifetime value regression code and results*/
PROC SQL;
CREATE TABLE Project.cust_lifetime_value as	 
SELECT a.Zip,a.donor_id,a.totaalamount,a.Total_Households,a.Avg_HH_Income,b.Family_households_,b.Nonfamily_households____Househol,c.Total_Population,c.Male,c.female,d.Total_Housing_Units,d.urban,d.semi_urban
FROM Project.cust_lifetime a, Project.householdtype b, Project.Populationbyageandgender c,Project.urbanruralhousingunits d
WHERE a.zip  = b.zip and a.zip  = c.zip and a.zip  = d.zip;
QUIT; 

proc reg data=project.cust_lifetime_value;
	MODEL totaalamount = Avg_HH_Income Total_Households;
run;


PROC CORR DATA = Project.cust_lifetime_value;
	VAR TotaalAmount Avg_HH_Income Total_households urban semi_urban;
RUN;

/**/

proc reg data=project.cust_lifetime;
	MODEL TotaalAmount = Avg_HH_Income Total_households;
run;

PROC CORR DATA = Project.cust_lifetime;
	VAR TotaalAmount Avg_HH_Income Total_households;
	WHERE TotaalAmount > 1000;
RUN;

PROC SQL;
Create Table Project.customer_data as           
SELECT donor_id,zipcode,SUM(gift_amount) AS SUM
FROM Project.Donations
GROUP BY donor_id,zipcode;          
RUN;

PROC SQL;
CREATE TABLE Project.cust_lifetime as	 
SELECT b.donor_id,b.SUM as TotaalAMount,a.zip,a.Total_Households,a.Avg_HH_Income
FROM Project.hhincomedistribution a, Project.customer_data b
WHERE a.Zip  = b.zipcode
ORDER BY b.SUM DESC;
QUIT; 


PROC CONTENTS data = Project.Donations;
run;

PROC SQL;
select count(distinct(donor_id)) from Project.Donations;
run;




PROC SQL;
CREATE TABLE Project.demo3 as
select appeal_id,SUM(appeal_cost) as TOTALAPPLEALSCOST
from Project.Appeals
group by appeal_id;
run;

PROC SQL;
CREATE TABLE Project.demo4 as
select appeal_id,SUM(gift_amount) as TOTALGIFTAMOUNT
from Project.Donations
group by appeal_id;
run;
PROC SQL;
CREATE TABLE Project.demo5 as
select appeal_id,appeal_date,SUM(appeal_cost) as TOTALAPPLEALSCOST
from Project.Appeals
group by appeal_id,appeal_date;
run;

PROC SQL;
CREATE TABLE Project.demo6 as
select appeal_id,gift_date,SUM(gift_amount) as TOTALGIFTAMOUNT
from Project.Donations
group by appeal_id,gift_date;
run;

PROC SQL;
CREATE TABLE Project.demo7 as
select a.appeal_id,gift_date,TOTALAPPLEALSCOST,TOTALGIFTAMOUNT
from Project.demo5 a,Project.demo6 b
where a.appeal_id=b.appeal_id;
run;

PROC SQL;
CREATE TABLE Project.demo8 as
select a.appeal_id,TOTALAPPLEALSCOST,TOTALGIFTAMOUNT,gift_date,appeal_date
from Project.demo5 a,Project.demo6 b
where a.appeal_id=b.appeal_id;
run;


/*******************************************piyush extra*******************************/
Proc SQL;
create table rfm.pre_rfmzip as
Select zipcode
	   ,sum(gift_amount) as monetary
	   ,count(gift_date) as freq
	   ,min(datdif(gift_date,test,'actual')) as day
from rfm.test
group by 1;
quit;

data clusters.segments;
set clusters.cluster;
drop rank frequency money;
run;

Proc rank data = clusters.segments out = clusters.two_grps groups = 2;
	var day freq monetary;
	ranks r f m;
run;

data clusters.rfm1; set clusters.two_grps;
if r = 0 and f = 1 and m = 1 then seg = 1;/*core donors*/
if r = 0 and f = 0 and m = 1 then seg = 2;/*new cust with high monetory val*/
if r = 0 and f = 1 and m = 0 then seg = 3;/*regular donors but less monetory*/
if r = 0 and f = 0 and m = 0 then seg = 4;/*newly aqquired cust less monetory*/
if r = 1 and f = 1 and m = 1 then seg = 5;/*customers who churned used to donate lage money*/
if r = 1 and f = 0 and m = 1 then seg = 6;/*used to donate high amount but less frequently*/
if r = 1 and f = 1 and m = 0 then seg = 7;/*customers who were loyal but churned*/
if r = 1 and f = 0 and m = 0 then seg = 8;/*cust who doneted in past but didn't come back*/
run;

/*reducing the segments ro 4 */

data clusters.zipsegments1;
set clusters.rfm1;
if seg = 1 then segment = 1;
if seg = 3 then segment = 1;
if seg = 2 then segment = 2;
if seg = 4 then segment = 2;
if seg = 5 then segment = 3;
if seg = 7 then segment = 3;
if seg = 6 then segment = 4;
if seg = 8 then segment = 4;
run;

data clusters.zipsegments;
set clusters.zipsegments1;
keep zipcode segment;
run;

/*meging demographic data*/

proc sql;
create table clusters.ziprfm as
select  zipsegments.zipcode, zipsegments.monetary, zipsegments.freq, zipsegments.day, zipsegments.segment,
mdemographicneeded.Total_Households, mdemographicneeded.Median_HH_Income, mdemographicneeded.Family_households_, mdemographicneeded.Nonfamily_households_,
mdemographicneeded.Total_population, mdemographicneeded.validMale2244, mdemographicneeded.Female2244
 from clusters.zipsegments
 join clusters.mdemographicneeded
 on zipsegments.zipcode = mdemographicneeded.zip;
 quit;