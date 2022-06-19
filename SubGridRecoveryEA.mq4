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


/*
//---Loggings
#include		<Orchard\Dialog\Dashboard.mqh>
CDashboard	*Dashboard;
string GridHeaderTxt = "Master Grid orders                                  " ;
string ColHeaderTxt =   "Ticket   Symbol   Type   LotSize   OpenPrice   Profit "  ;
int DashboardSize = 10;
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
	Dashboard	=	new CDashboard("MasterGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 8                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 
	                              
	//Dashboard.AddRow(CharToStr(232), clrWhite, "Wingdings", 20);
	Dashboard.AddRow(GridHeaderTxt, clrWhite, "Verdana", 10);
	Dashboard.AddRow("", clrWhite, "Verdana", 10);
	Dashboard.AddRow(ColHeaderTxt, clrWhite, "Verdana", 8);

	//--- Add 10+ blank row to get the space for the list
	for(int i=0;i<DashboardSize-1;i++)
	  {
	   Dashboard.AddRow("", clrWhite, "Verdana", 8);
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
   
   Grid.ShowGridOrdersOnChart(Grid.mOrders);

		  
  }


//+------------------------------------------------------------------+

