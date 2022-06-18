//Get the MostRecentOrderTicket
   for(int b=OrdersHistoryTotal()-1; b >=0; b--) // loop thru opening order
     {
      if(OrderSelect(b,SELECT_BY_POS,MODE_HISTORY))
        {
         //Print("[GetMostRecentTicketClose] ", "OrderTicket:" , OrderTicket(), ", OrderCloseTime: ",OrderCloseTime());
         if(OrderCloseTime() == MostRecentOrderCloseTime)
           {
            MostRecentOrderClosedTicket = OrderTicket();
            //Print("Line[227]: The most recent order ticket of " , Symbol()," is ", MostRecentOrderClosedTicket);
            break;
           }

         else
            continue;
        }

     }
   return(MostRecentOrderCloseTime);
  }
  
  