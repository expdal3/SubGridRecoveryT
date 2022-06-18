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
#include <Arrays/ArrayInt.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Blues/TradeInfoClass.mqh>

CTradeInfo * tradeInfo;
CArrayObj * masterGrid = new CArrayObj();

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int historyTotal = OrdersHistoryTotal();
int openTotal = OrdersTotal();
double AcctBalance,   AcctEquity;
int gridSize;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   AcctBalance=AccountBalance();
   AcctEquity = AccountEquity();
   tradeInfo = new CTradeInfo();
   gridSize = ArraySize(OpenTrades);
   tiebreak=false;
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
   OpenGridTrades(sum);
   
   /*
   //If trade allowed and no positions exists by any chart - open a new set of grid orders
   //if(IsNewBar() && IsTradeAllowed() && !IsTradeContextBusy())
   //  {
   //   quickMartingale();
      
      /*
      if(gridSize < ArraySize(OpenTrades))
        {
         PrintFormat("There are %d trade opened", ArraySize(OpenTrades));
         for(int i=0; i<ArraySize(OpenTrades); i++)
           {
            PrintFormat("ticketNumber: %d , OpenPrice: %s, LotSize: %s, StopLoss: %s, TakeProfit: %s comment: %s ",
                        OpenTrades[i].Ticket,OpenTrades[i].OpenPrice, OpenTrades[i].Lots, OpenTrades[i].StopLoss, OpenTrades[i].TakeProfit,OpenTrades[i].Comment);
           }
         gridSize = ArraySize(OpenTrades);
        }
      }
      */
      //---

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void test(string symbol)
  {
   PrintFormat("Base currency is %s", AccountCurrency());
   PrintFormat("Testing for symbol %s", symbol);

   double pointValue = PointValue(symbol);
   PrintFormat("ValuePerPoint for %s is %f", symbol, pointValue);
  }

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
