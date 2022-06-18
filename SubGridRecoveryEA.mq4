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
CGrid *Grid;
CArrayObj * masterGrid = new CArrayObj();

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
   Grid = new CGrid();
   gridSize = ArraySize(OpenTrades);
   tiebreak=false;
   bool OrderOpenedChange=false;


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
      Grid.GetOrdersOpened(Grid.mOrdersArray,InpMagicNumber);           //pass data to Grid array that match magicnumber
     }

  
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

/*
if(historyTotal>0)
  {
  tradeInfo.GetClosed(62252388);
   Print("OpenPrice =",tradeInfo.mSelectedOrder.OpenPrice);
   Print("MagicNumber =",tradeInfo.mSelectedOrder.MagicNumber);
  }

if(openTotal>0)
  {
  tradeInfo.GetOpened(62256402);
   Print("OpenPrice =",tradeInfo.mSelectedOrder.OpenPrice);
   Print("MagicNumber =",tradeInfo.mSelectedOrder.MagicNumber);
  }
 */

//+------------------------------------------------------------------+

