//+------------------------------------------------------------------+
//|                              Orchard_SimpleGridTradeTemplate.mq4 |
//|                                       Copyright 2022, BlueStone. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#include <Blues/UtilityFunctions.mqh>



extern int               InpMaxTrades      = 30;             //Max number of trades allowed
extern double            InpStepGrid       = 200;            // StepGrid
//extern ENUM_ORDER_TYPE   InpType           = ORDER_TYPE_SELL; //Order type
extern ENUM_TRADE_MODES        InpTradeMode      = Buy_and_Sell;   // TradeMode   
extern double            InpMinProfit      = 5.00;           // GridTakeProfit 
//extern int               InpMagicNumber    =  1111;        // Magic number
//extern string            InpTradeComment   = __FILE__;     // Trade comment
extern double            InpLot         = 0.01;              //LotSize per order
extern double            InpFactor      = 1.5;               //LotSize Multiplier

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
  
void OpenGridTrades(STradeSum &sum, int ordertype, int inpmagicnumber, string inpcomment){

  if(sum.profit>InpMinProfit){  // target reached
      CloseAll(ordertype, inpmagicnumber);
   }else{
   if(sum.count==0){ // no trades opened yet
      OpenTrade(sum,ordertype, inpmagicnumber, inpcomment);
   }else{
      if(sum.count<InpMaxTrades){
         if(ordertype==ORDER_TYPE_BUY
            && SymbolInfoDouble(Symbol(),SYMBOL_ASK)<=(sum.trailPrice-PointsToPrice(InpStepGrid))){   // Far enough below
               OpenTrade(sum, ordertype, inpmagicnumber, inpcomment);
           }else{
           if(ordertype==ORDER_TYPE_SELL
            && SymbolInfoDouble(Symbol(),SYMBOL_BID)>=(sum.trailPrice+PointsToPrice(InpStepGrid))){   // Far enough above
               OpenTrade(sum, ordertype,inpmagicnumber, inpcomment);
             }
           }
        }
      }
   }
}
//+------------------------------------------------------------------+

void OpenTrade(STradeSum &sum, int ordertype, int magicnumber, string comment){
   double price = (ordertype==ORDER_TYPE_BUY)?
                        SymbolInfoDouble(Symbol(), SYMBOL_ASK) :
                        SymbolInfoDouble(Symbol(), SYMBOL_BID) ;
   double _lot = (sum.count==0)?
                        InpLot:
                        sum.trailLot*InpFactor;
                 
   double _incre = 0.0;                     
   if(tiebreak==true && InpFactor>1)
     {
      _incre = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
      tiebreak=false;
     }
   
   int ticket= OrderSend(Symbol()
            ,ordertype
            ,_lot + _incre
            ,price
            ,0                // Slip
            ,0                // SL
            ,0                // TP  
            ,comment
            ,magicnumber
            );
   if(ticket==-1)PrintFormat(__FUNCTION__+"LastError is %d", GetLastError());                                    
}

void CloseAll(int ordertype, int magicnumber){
   int count = OrdersTotal();
   
   for(int i=count-1;i>=0;i--)
     {
     if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
       {
        if(OrderSymbol()==Symbol()
           &&  OrderMagicNumber() == magicnumber
           &&  OrderType() ==  ordertype 
            )
          {
            OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0);
          }
       }
      
     }
}

void GetSum(STradeSum &sum, int ordertype, int magicnumber){
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
            && OrderMagicNumber() == magicnumber
            && OrderType()==   ordertype)
           {
            sum.count++;
            sum.profit  += OrderProfit()+OrderSwap()+OrderCommission();
            if(ordertype==ORDER_TYPE_BUY)
              {
               if(sum.trailPrice==0 || OrderOpenPrice()<sum.trailPrice)
                 {
                  sum.trailPrice = OrderOpenPrice();
                 }
              }
             else
                 {
                  if(ordertype==ORDER_TYPE_SELL)
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

