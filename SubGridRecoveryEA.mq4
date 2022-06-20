//+------------------------------------------------------------------+
//|                                            SubGridRecoveryEA.mq4 |
//|                                       Copyright 2022, BlueStone. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, BlueStone."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "include/GridTradeFunction.mqh"
#include "include/GridOrderManagement.mqh"
#include "include/LogsFunction.mqh"
#include <Arrays/ArrayInt.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Blues/TradeInfoClass.mqh>

extern  int OrderToStartDDReduce =  7  ; // Order To Start DD Reduce

CTradeInfo *tradeInfo;
CGridMaster *Grid;

//---declare dashboard logggings
CDashboard DashboardMaster("MasterGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 500                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 
   
CDashboard DashboardSub("SubGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 3                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 

string MasterGridHeaderTxt = "Master Grid orders                                  " ;
string SubGridHeaderTxt = "Sub Grid orders                                  ";
string ColHeaderTxt =   "Ticket   Symbol   Type   LotSize   OpenPrice   Profit "  ;
int TotalRowsSize = 10;
int HeaderRowsToSkip = 3;



/*
//---Loggings
#include		<Orchard\Dialog\Dashboard.mqh>
CDashboard	*Dashboard;
string GridHeaderTxt = "Master Grid orders                                  " ;
string ColHeaderTxt =   "Ticket   Symbol   Type   LotSize   OpenPrice   Profit "  ;

int DashboardRowsToSkip=3;
*/

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//internal parameters
int historyTotal = OrdersHistoryTotal();
int openTotal = OrdersTotal();
double AcctBalance,   AcctEquity;
int gridSize;
int _OrdersTotal = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   AcctBalance=AccountBalance();
   AcctEquity = AccountEquity();
   tradeInfo = new CTradeInfo();
   //--- Declare grid objects
   Grid = new CGridMaster();                 // new Grid objects
   tiebreak=false;
   bool OrderOpenedChange=false;

   //--- Loggings Init - Create 2 dashboard
   AddGridDashboard(DashboardMaster, "MasterGridDB", MasterGridHeaderTxt, ColHeaderTxt);
   AddGridDashboard(DashboardSub, "SubGridDB", SubGridHeaderTxt, ColHeaderTxt);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   // Start martingale trades
   STradeSum sum;
   GetSum(sum);
   if(IsTradeAllowed() && !IsTradeContextBusy()) OpenGridTrades(sum);   
   
   //Collect data to array
   if(IsNewBar() )
     {
      Grid.GetOrdersOpened(Grid.mOrders,InpMagicNumber);           //pass data to Grid array that match magicnumber
      Grid.GetSubGridOrders(Grid.mSubGrid,Grid.mSize,OrderToStartDDReduce);
     }

   static datetime	currentTime;
	if (currentTime!=Time[0]) {
		Grid.ShowGridOrdersOnChart(DashboardSub, Grid.mSubGrid, 3);   //pass subGrid orders to Dashboard Sub
      
      Grid.ShowGridOrdersOnChart(DashboardMaster, Grid.mOrders, 3);  //pass main orders to Dashboard Sub
 
		currentTime	=	Time[0];
	}  
  }


//+------------------------------------------------------------------+


void AddGridDashboard(CDashboard &dashboard
                     , string dashboardObjName
                     , string tableheadertxt
                     , string colheadertxt
                     , int rows = 10
                     , int corner = CORNER_RIGHT_UPPER
                     , int xdist = 400
                     , int ydist =  15
                     , color txtclr =  clrWhite
                     , string txtfont  =  "Verdana"
                     , int txtsize  =  10
                     ){
   //---

	
	                              
	//DashboardMaster.AddRow(CharToStr(232), clrWhite, "Wingdings", 20);
	dashboard.AddRow(tableheadertxt, txtclr, txtfont, txtsize);
	dashboard.AddRow("", txtclr, txtfont, txtsize-2);
	dashboard.AddRow(colheadertxt, txtclr, txtfont, txtsize-2);
	
   //--- Add 10+ blank row to get the space for the list
	for(int i=0;i<rows-1;i++)
	  {
	   dashboard.AddRow("", txtclr, txtfont, txtsize-2);
	  }
}