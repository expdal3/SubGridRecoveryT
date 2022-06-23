//+------------------------------------------------------------------+
//|                              Orchard_SimpleGridTradeTemplate.mq4 |
//|                                       Copyright 2022, BlueStone. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Blues/UtilityFunctions.mqh>

extern int               InpMaxTrades      = 30;             //Max number of trades allowed
extern double            InpStepGrid       = 200;            //Min gap in point between trades
extern ENUM_ORDER_TYPE   InpType           = ORDER_TYPE_SELL; //Order type
extern double            InpMinProfit      = 1.00;           //Profit in base currency
extern int               InpMagicNumber    =  1111;          //Magic number
extern string            InpTradeComment   = __FILE__;       //Trade comment
extern double            InpLot         = 0.01;              //LotSize per order
extern double            InpFactor      = 1.5;                  //LotSize Multiplier

bool  tiebreak;
struct STradeSum
  {int      count;
   double   profit;
   double   trailPrice;
   double   trailLot;
   
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
  
void OpenGridTrades(STradeSum &sum){
  if(sum.profit>InpMinProfit){  // target reached
      CloseAll();
   }else{
   if(sum.count==0){ // no trades opened yet
      OpenTrade(sum);
   }else{
      if(sum.count<InpMaxTrades){
         if(InpType==ORDER_TYPE_BUY
            && SymbolInfoDouble(Symbol(),SYMBOL_ASK)<=(sum.trailPrice-PointsToPrice(InpStepGrid))){   // Far enough below
            PrintFormat("AskPrice is %.4f, sum.trailPrice is %.4f ", SymbolInfoDouble(Symbol(),SYMBOL_ASK), sum.trailPrice);
               OpenTrade(sum);
           }else{
           if(InpType==ORDER_TYPE_SELL
            && SymbolInfoDouble(Symbol(),SYMBOL_BID)>=(sum.trailPrice+PointsToPrice(InpStepGrid))){   // Far enough above
                  PrintFormat("BidPrice is %.4f, sum.trailPrice is %.4f ", SymbolInfoDouble(Symbol(),SYMBOL_BID), sum.trailPrice);

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
   PrintFormat("_lot %.2f , sum.count %d", _lot, sum.count);
   PrintFormat(" Type is %s", InpType );                     
   double _incre = 0.0;                     
   if(tiebreak==true && InpFactor>1)
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
            
          if(sum.trailLot==OrderLots() && InpFactor>1.00)         //tiebreaker
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



