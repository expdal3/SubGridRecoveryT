#include <Blues/TradeInfoClass.mqh>

void LogOpenedOrder(SOrderInfo &arr[1], int _ordertotal){

   if(_ordertotal!=OrdersTotal())
     {  
      for(int i=ArraySize(arr)-1;i>=0;i--) PrintFormat("Order Ticket %d, OpenPrice %.4f in GridArray", arr[i].Ticket, arr[i].OpenPrice);
      _ordertotal = OrdersTotal();
      }
   }