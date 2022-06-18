//+------------------------------------------------------------------+
//|                              Orchard_SimpleGridTradeTemplate.mq4 |
//|                                       Copyright 2022, BlueStone. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, BlueStone."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input int               InpMaxTrades      = 10;             //Max number of trades allowed
input double            InpStepGrid       = 200;            //Min gap in point between trades
input ENUM_ORDER_TYPE   InpType           = ORDER_TYPE_BUY; //Order type
input double            InpMinProfit      = 1.00;           //Profit in base currency
input int               InpMagicNumber    =  1111;          //Magic number
input string            InpTradeComment   = __FILE__;       //Trade comment
input double            InpLot         = 0.01;              //LotSize per order
input double            InpFactor      = 1;                  //LotSize Multiplier
bool  tiebreak;
struct STradeSum
  {int      count;
   double   profit;
   double   trailPrice;
   double   trailLot;
   
  };

int OnInit()
  {
//---
   tiebreak=false;
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   STradeSum sum;
   GetSum(sum);
   
   if(sum.profit>InpMinProfit){  // target reached
      CloseAll();
   }else{
   if(sum.count==0){ // no trades opened yet
      OpenTrade(sum);
   }else{
      if(sum.count<InpMaxTrades){
         if(InpType==ORDER_TYPE_BUY
            && SymbolInfoDouble(Symbol(),SYMBOL_ASK)<=(sum.trailPrice-PointsToPrice(InpStepGrid))){   // Far enough below
               OpenTrade(sum);
           }else{
           if(InpType==ORDER_TYPE_SELL
            && SymbolInfoDouble(Symbol(),SYMBOL_BID)>=(sum.trailPrice+PointsToPrice(InpStepGrid))){   // Far enough above
               OpenTrade(sum);
             }
           }
        }
      }
   }

  }
//+------------------------------------------------------------------+

void OpenTrade(STradeSum &sum){
   double price = (InpType==ORDER_TYPE_BUY)?
                        SymbolInfoDouble(Symbol(), SYMBOL_ASK) :
                        SymbolInfoDouble(Symbol(), SYMBOL_BID) ;
   double _lot = (sum.count==0)?
                        InpLot:
                        sum.trailLot*InpFactor;
   double _incre = 0.0;                     
   if(tiebreak==true)
     {
      _incre = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
      tiebreak=false;
     }
   OrderSend(Symbol()
            ,InpType
            ,_lot + _incre
            ,price
            ,0                // Slip
            ,0                // SL
            ,0                // TP  
            ,InpTradeComment
            ,InpMagicNumber
            );                     
}

void CloseAll(){
   int count = OrdersTotal();
   
   for(int i=count-1;i>=0;i--)
     {
     if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
       {
        if(OrderSymbol()==Symbol()
           &&  OrderMagicNumber() == InpMagicNumber
           &&  OrderType() ==  InpType 
            )
          {
            OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0);
          }
       }
      
     }
}

void GetSum(STradeSum &sum){
   int   count =  OrdersTotal();
   
   sum.count   =  0;
   sum.profit  =  0.0;
   sum.trailPrice =  0.0;
   sum.trailLot   =  0.0;
   
   for(int i=count-1;i>=0;i--)
     {
     if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
       {
         if(OrderSymbol()==Symbol()
            && OrderMagicNumber() == InpMagicNumber
            && OrderType()==   InpType)
           {
            sum.count++;
            sum.profit  += OrderProfit()+OrderSwap()+OrderCommission();
            if(InpType==ORDER_TYPE_BUY)
              {
               if(sum.trailPrice==0 || OrderOpenPrice()<sum.trailPrice)
                 {
                  sum.trailPrice = OrderOpenPrice();
                 }
               else
                 {
                  if(InpType==ORDER_TYPE_SELL)
                    {
                     if(sum.trailPrice==0 || OrderOpenPrice()>sum.trailPrice)
                       {
                        sum.trailPrice = OrderOpenPrice();
                       }
                    }
                 }
              }
              if(sum.trailLot==OrderLots())         //tiebreaker
               {
                  tiebreak=true;
               }else{
               if(sum.trailLot==0 || sum.trailLot<OrderLots())     // first order of the basket
                  {
                   sum.trailLot=OrderLots();
                  }
                     tiebreak=false;
                  }
            

               
             //Print("sum.trailLot = ", sum.trailLot    );
           }
       }
     }   
}
double   PointsToPrice(double points)                 
   {return(points*SymbolInfoDouble(Symbol(), SYMBOL_POINT));}

