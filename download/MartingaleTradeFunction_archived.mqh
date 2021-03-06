//+------------------------------------------------------------------+
//|                                   Simple Martingale Template.mq4 |
//|                           Copyright © 2015, Joel Tagle Protusada |
//|                     https://www.facebook.com/groups/FXFledgling/ |
//+------------------------------------------------------------------+

/*===================================================================//
A simple but fully functional program that demonstrate how a martingale 
can work for you. Just change the entry analyis using your own scalping 
strategy and your personal money management style, then optimize. 
If your goal is a consistent profit, NOT a high-percentage one and 
willing to use a big capital. This script maybe for you. Optimize it 
first with a capital that gives a maximum drawdown of not more than 50%. 
To be conservative, less than 30% is ideal.

If you are looking for an EA with a profit of 100% per year or more, 
this is not for you. Just don't be greedy and just aim for reasonable 
profit percentage (e.g. 5% to 50% per year)  

FULL DISCUSSION: Details of this script and the logic behind it is discussed
in the ebook; Uncharted Stratagems: Unknown Depths of Forex Trading. This book
tackles the entry-level learning of Maneuver Analysis. This strategy is just one 
of the in-depth topics you can get from the book. Latest edition will be
released in October 2021. You can pre-order now.

HOW TO PRE-ORDER UNCHARTED STRATAGEMS
Step 1: Buy Grid-Averaging Bot at https://www.mql5.com/en/market/product/45236
Step 2: Give it a 5-Star Review
Step 3: Wait for 7-day Payment Grace Period in MQL5 site. After 7 days, you will 
receive initial draft of the e-book. Then the complete version in October 2021.

BONUS if you pre-order on or before January 31, 2021: You will get the Source Code
of Grid-Averaging Bot so you can review topics discussed in the ebook, 
Uncharted Stratagems. 


===============================================================================
ADVANCED LEARNING E-BOOK: 

1) FOREX OVERLORD: Mastering Control in Forex Trading with Advanced Maneuver 
   Analysis and More Strategies for Higher Profitability.
   To be released: in 2023 - You can pre-order now.
   
2) FOREX VAULT: A Treasure Collection of Successful Forex Robot Source Codes 
   Covered in FOREX OVERLORD. 
   To be released: in 2023 - You can pre-order now.
===============================================================================   


DISCLAIMER: This script is for educational purposes only. If you decided 
to use this script on live trading, please pratice due diligence on
what entry analysis and indicators that you are going to use with
thorough optimization, and long-term demo forward testing. Forex is 
a high-risk endeavour and you should not invest money that you can not 
afford to lose.  
//===================================================================*/

#include <Blues/UtilityFunctions.mqh>
#include <Blues/TradeInfoClass.mqh>

//=========Default Parameters is for EURUSD H1 chart=================//
//Optimize it with the pair and timeframe that you like to test.

//-----------Trade Parameters
extern int    EaMagicNumber        = 123456;//Magic number
extern string EaComment          = "Martingale";//Order comment
extern double StopLossPoint      = 100000;
extern double TakeProfitPoint    = 250;
extern double StartLot           = 0.01;
//-----------Martingale Parameter
extern double Multiplier         =1.5;
extern double GridStepPoint      = 350;//Step between grid orders in point

//-----------Indicator & Entry Analysis Parameters
//=================================================
//Put here the parameters of your own analysis
extern int    TimeFrame  = 60;
extern int    fastperiod = 50;
extern int    slowperiod = 200;
//=================================================

//-----------Variables
double _Lot         = 0.01;
double AcctBalance = 0.0;
double AcctEquity = 0.0;
bool   Go          = true;

Orders OpenTrades[];
//declare new CArrayObject:


//+------------------------------------------------------------------+

void quickMartingale(){

   if(OrdersTotal()==0 && AcctBalance!=AccountBalance())
     {
      if(AcctBalance>AccountBalance())
        {
         _Lot=Multiplier*_Lot;
         Go = true;
        }
      else if(AcctBalance<AccountBalance())
        {
         _Lot=StartLot;
         Go = true;
        }
     }

   if(OrdersTotal()==0 && Go)
     {
      AcctEquity=AccountEquity();
      AcctBalance=AccountBalance();
      int order;
      
      //=================Change this with your own entry analysis=============================
      double fast = iMA(Symbol(),TimeFrame,fastperiod,0,MODE_SMA,PRICE_CLOSE,1);
      double slow = iMA(Symbol(),TimeFrame,slowperiod,0,MODE_SMA,PRICE_CLOSE,1);
      double c    = iClose(Symbol(),TimeFrame,1);

      double fast2 = iMA(Symbol(),TimeFrame,fastperiod,0,MODE_SMA,PRICE_CLOSE,2);
      double slow2 = iMA(Symbol(),TimeFrame,slowperiod,0,MODE_SMA,PRICE_CLOSE,2);
      double H     = iHigh(Symbol(),TimeFrame,2);
      double L     = iLow(Symbol(),TimeFrame,2);
      //======================================================================================

      if(c>fast && fast>slow && fast2<slow2 && c>H) //Change this with your buy condition
        {
         order=OrderSend(Symbol(),OP_BUY,_Lot,Ask,0,Bid-StopLossPoint*Point,Ask+TakeProfitPoint*Point,EaComment,EaMagicNumber);
         
         AddOrderToGrid(OpenTrades,
                           order,              //ordertic
                           Symbol(),           //symbol
                           OP_BUY,             //type, 
                           _Lot,               //lot
                           Ask,                //openprice
                           Bid-StopLossPoint*Point,   //stoploss
                           Ask+TakeProfitPoint*Point, //takeprofit
                           EaComment,                 //comment
                           EaMagicNumber              //magicnumber 
                     );
         
         Go=false;
        }
      else if(c<fast && fast<slow && fast2>slow2 && c<L) //Change this with your sell condition
        {
         order=OrderSend(Symbol(),OP_SELL,_Lot,Bid,0,Ask+StopLossPoint*Point,Bid-TakeProfitPoint*Point,EaComment,EaMagicNumber);
         AddOrderToGrid(OpenTrades,
                     order,              //ordertic
                     Symbol(),           //symbol
                     OP_SELL,             //type, 
                     _Lot,               //lot
                     Bid,                //openprice
                     Ask+StopLossPoint*Point,   //stoploss
                     Bid-TakeProfitPoint*Point, //takeprofit
                     EaComment,                 //comment
                     EaMagicNumber              //magicnumber
                  );

         Go=false;
        }
     }


}
//+------------------------------------------------------------------+
//|  Fill grid's order details 
//| -------------------------------
//|   When trade in real, collect these data from tradeHistory dataset 
//+------------------------------------------------------------------+

void FillGridOrder(
                  Orders &thisOrder, 
                  int ordertic,
                  string symbol,
                  string type,
                  double lot,
                  double openprice,
                  double stoploss,
                  double takeprofit,
                  string comment,
                  int magicnumber  
                                     
){
    
   thisOrder.Ticket = ordertic;
   thisOrder.Symbol = symbol;
   thisOrder.Type = OrderTypeName(type);
   thisOrder.Lots = DoubleToString(lot,2);
   thisOrder.OpenPrice = DoubleToString(openprice,MarketInfo(symbol,MODE_DIGITS));
   thisOrder.StopLoss= DoubleToString(stoploss,MarketInfo(symbol,MODE_DIGITS));
   thisOrder.TakeProfit = DoubleToString(takeprofit,MarketInfo(symbol,MODE_DIGITS));
   thisOrder.Comment= comment;
   thisOrder.MagicNumber= magicnumber;
}

//---

void AddOrderToGrid(Orders &arr[1],
                  int ordertic,
                  string symbol,
                  string type,
                  double lot,
                  double openprice,
                  double stoploss,
                  double takeprofit,
                  string comment,
                  int magicnumber  
                  ){
   
   //Add new pos to the array
   ArrayResize(arr,ArraySize(arr)+1);

   //Copy the existing element one pos to the left
   if(ArraySize(arr)>1)                                       //Copy all the element to the left
     {
         for(int i=ArraySize(arr)-1;i>0;i--){
               arr[i].Ticket = arr[i-1].Ticket;
               arr[i].Symbol = arr[i-1].Symbol;
               arr[i].Type = arr[i-1].Type;
               arr[i].Lots = arr[i-1].Lots;
               arr[i].OpenPrice = arr[i-1].OpenPrice;
               arr[i].TakeProfit = arr[i-1].TakeProfit;
               arr[i].StopLoss= arr[i-1].StopLoss;
               arr[i].Comment= arr[i-1].Comment;
               arr[i].MagicNumber= arr[i-1].MagicNumber;
               
        }
     }
   
    //add new order to pos 0
    FillGridOrder(arr[0],  
                  ordertic,              //ordertic
                  symbol,           //symbol
                  type,             //type, 
                  lot,               //lot
                  openprice,                //openprice
                  stoploss,   //stoploss
                  takeprofit, //takeprofit
                  comment,                 //comment
                  magicnumber              //magicnumber
                  );  
}
        