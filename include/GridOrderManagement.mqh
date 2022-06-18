

#include <Blues/UtilityFunctions.mqh>
#include <Blues/TradeInfoClass.mqh>
SOrderInfo OpenTrades[];
//declare new CArrayObject:
//+------------------------------------------------------------------+

class CGrid: public CTradeInfo
  {
public:
      SOrderInfo  mOrdersArray[];
      double      mMaxLotSize;         
public:
                  CGrid(void){};
                  ~CGrid();

  };



//+------------------------------------------------------------------+
//|  Fill grid's order details 
//| -------------------------------
//|   When trade in real, collect these data from tradeHistory dataset 
//+------------------------------------------------------------------+

void FillGridOrder(
                  SOrderInfo &thisOrder, 
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

void AddOrderToGrid(SOrderInfo &arr[1],
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
        