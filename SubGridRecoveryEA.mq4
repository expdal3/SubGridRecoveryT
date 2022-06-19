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


CTradeInfo * tradeInfo;
CGridMaster *Grid;

CDashboard  *Dashboard;
CDashboard	*DashboardMaster;
CDashboard	*DashboardSub;
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


   //--- Loggings Init
   //---
	DashboardMaster	=	new CDashboard("MasterGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 400                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 
	
	                              
	//DashboardMaster.AddRow(CharToStr(232), clrWhite, "Wingdings", 20);
	DashboardMaster.AddRow(MasterGridHeaderTxt, clrWhite, "Verdana", 10);
	DashboardMaster.AddRow("", clrWhite, "Verdana", 10);
	DashboardMaster.AddRow(ColHeaderTxt, clrWhite, "Verdana", 8);

	//--- Add 10+ blank row to get the space for the list
	for(int i=0;i<TotalRowsSize-1;i++)
	  {
	   DashboardMaster.AddRow("", clrWhite, "Verdana", 8);
	  }
   
   //---
   //SubGrid
   DashboardSub	=	new CDashboard("SubGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 8                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 
	
	                              
  	DashboardSub.AddRow(SubGridHeaderTxt, clrWhite, "Verdana", 10);
	DashboardSub.AddRow("", clrWhite, "Verdana", 10);
	DashboardSub.AddRow(ColHeaderTxt, clrWhite, "Verdana", 8);

	//--- Add 10+ blank row to get the space for the list
	for(int i=0;i<TotalRowsSize-1;i++)
	  {
	   DashboardSub.AddRow("", clrWhite, "Verdana", 8);
	  }
     
   

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
      
     }
   
   Grid.ShowGridOrdersOnChart(DashboardMaster, Grid.mOrders, 3);
   Grid.ShowGridOrdersOnChart(DashboardSub, Grid.mOrders, 3);
   
		  
  }


//+------------------------------------------------------------------+

