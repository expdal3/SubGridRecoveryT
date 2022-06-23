//--- includes
#include <Blues/UtilityFunctions.mqh>
#include <Blues/TradeInfoClass.mqh>

//---Loggings
#include		<Orchard\Dialog\Dashboard.mqh>

//DashboardMaster.= 10;
//DashboardRowsToSkip=3;

//---structs
struct SSubGrid{                             // Sub-grid structure to hold sub-grid orders and its metadata
   SOrderInfo        BottomOrder;            //  deepest DD order-small lotsize
   SOrderInfo        MidOrder;               //  middle DD order of the grid - medium size lotsize in MasterGrid
   SOrderInfo        TopOrder;               // Top order of the sub-grid - currently largest size of the MasterGrid 
   int               BottomOrderPos;
   int               MidOrderPos;
   int               TopOrderPos;
   SOrderInfo        PrevClosedTopOrder;     // (trailing) the latest closed top order : this can be used for Order Replacement Feature
   double            Profit;                 // Sum of profit for the sub-grid
};

class CGridBase: public CTradeInfo
  {
public:
   SOrderInfo           mOrders[];                    // arrays to hold grid's orders info
   SOrderInfo_BinFormat mBinOrders[];                 // arrays holding only Seq and Ordertic info - to save to binfile
   int                  mSize;                        // size of grid
   double               mProfit;                      // profit of grid
   double               mMaxLotSize;                  // (trailing) maximum lotsize of grid
   double               mMinLotSize;                  // (trailing) minimum lotsize of grid
   datetime             mLatestTradeOpenedTime;       // (trailing) latest trade open time in the grid
   bool                 mIsRecovering;                 // True/false, status of grid being recovered or not

public:
                     CGridBase(void){};
                    ~CGridBase(void);
         
};



//declare new CGrid Class:
//+------------------------------------------------------------------+

class CGridMaster: public CGridBase
  {
public:
      SSubGrid    mSubGrid;                  //subgrid struct of the Master Grid
      int         mOrderType;
      int         mMagicNumber;
public:
                  CGridMaster(){Init(mSubGrid);};
                  CGridMaster(int ordertype,int magicnumber):mOrderType(ordertype),mMagicNumber(magicnumber){Init(mSubGrid);};
                  ~CGridMaster();
      //---
      int         Init(SSubGrid &subgrid);
      //---
      virtual void      ConvertToBinFormat(){ 
         ArrayResize(mBinOrders, ArraySize(mOrders));
         for(int i=0;i<ArraySize(mOrders) ;i++)
           {
               mBinOrders[i].SequenceNumber = mOrders[i].SequenceNumber;
               mBinOrders[i].Ticket         = mOrders[i].Ticket;      
           }
         };         
                          
      
      //---       read orders for Master grid
      virtual void  GetOrdersOpened(SOrderInfo &arr[1], int magicnumber=0, string comment=NULL);
      virtual void  GetOrdersHistory(SOrderInfo &arr[1], int magicnumber=0, string comment=NULL); 
      virtual int    SetOrderToGrid(SOrderInfo &gridpos, int ordetic, int pool=MODE_TRADES);                    //fill all order details from the input orderticket
      virtual void  RefillGridWithSavedData(SOrderInfo &arr[1], SOrderInfo_BinFormat &binarr[1] );
      
      //---       read orders to Sub grid
      int         GetSubGridOrders(SSubGrid &subgrid, int gridsize, int orderstostartddreduce);
      
      //---       orders removal
      void        RemoveOrderFromGrid(SOrderInfo &mastergrid[1], CTradeInfo &trade, int ordertic);            //remove an order from grid and shiftup using an order ticket

      
      //---       Profit & stats calculation
      void        GetGridStats();                                                                              //Get the latest Grid's stats: profit, min/maxlotsize, latest trade opened, IsRecovering status, 
      int         GetGridSize(){mSize = ArraySize(mOrders);return(mSize);};
      double      GetProfit();
      double      GetMaxLotSize();
      double      GetMinLotSize();
      int         GetLatestTradeOpenedTime();
      bool        GetState(SSubGrid &subgrid);
      
      //---       Orders close
      void        CloseSubGrid(SSubGrid &subgrid, double profittoclose);
         
      //---       Loggings          
      void        ShowGridOrdersOnChart(CDashboard &dashboard, SOrderInfo &orders[1], int _headerrowstoskip);
      void        ShowGridOrdersOnChart(CDashboard &dashboard, SSubGrid &subgrid, int _headerrowstoskip);
protected:
      void        ResetSubGridOrders(SSubGrid &subgrid){ResetOrderData(subgrid.BottomOrder);
                                                        ResetOrderData(subgrid.MidOrder);
                                                        ResetOrderData(subgrid.TopOrder);
                                                      };            //remove an order from grid and shiftup using an order ticket 

};

int  CGridMaster::Init(SSubGrid &subgrid){
      ResetOrderData(subgrid.BottomOrder);
      ResetOrderData(subgrid.MidOrder);
      ResetOrderData(subgrid.TopOrder);
      
      subgrid.BottomOrderPos=0;
      subgrid.MidOrderPos=0;
      subgrid.TopOrderPos=0;
      
      mIsRecovering=false;   //initialize mIsRecovery status - set to false
      
      return(INIT_SUCCEEDED);
}

//bool CGridMaster::mIsRecovery = false;
//---modify GetOrdersOpened() and GetOrdersHistory() as inherit from CTradeInfo() using virtual function
//+------------------------------------------------------------------+
//|  Grid stats                                                      |
//+------------------------------------------------------------------+

void  CGridMaster::GetGridStats(){
   
   GetGridSize();                         // Grid Size
   GetMinLotSize();                     // MinLotSize
   GetMaxLotSize();                       // MaxLotSize   
   GetProfit();                           // Profit
   GetLatestTradeOpenedTime();            // LatestTradeOpenedTime
   GetState(mSubGrid);                           // IsRecovering ?
   
}

double CGridMaster::GetProfit()
{  
   double profit = 0.0;
   for(int i=0;i<ArraySize(mOrders);i++){
      profit += mOrders[i].Profit;
   }
   mProfit = profit;
   return (profit);
}

double CGridMaster::GetMaxLotSize()
{  
   double maxlot = 0.0;
   
   for(int i=0;i<ArraySize(mOrders);i++){
      if(maxlot < mOrders[i].Lots) maxlot = mOrders[i].Lots;
      else continue;
   }
   mMaxLotSize = maxlot;
   return (maxlot);
}

double CGridMaster::GetMinLotSize()
{  
   double minlot = 1000.0;
   
   for(int i=ArraySize(mOrders)-1;i>=0;i--){
      if(minlot > mOrders[i].Lots) minlot = mOrders[i].Lots;
      else continue;
   }
   mMinLotSize = minlot;
   return (minlot);
}

int   CGridMaster::GetLatestTradeOpenedTime()
{
   int latestopenedtime = 0;
   
   for(int i=0;i<ArraySize(mOrders);i++)
     {
      if(latestopenedtime<(int)mOrders[i].OpenTimeDt) latestopenedtime = (int)mOrders[i].OpenTimeDt;
        else continue;
     }
   mLatestTradeOpenedTime = latestopenedtime;
   return (latestopenedtime);
}

bool  CGridMaster::GetState(SSubGrid &subgrid){
   if(subgrid.TopOrderPos!=0) mIsRecovering = true;
   else mIsRecovering = false;
   return (mIsRecovering);
}

//---

void  CGridMaster::GetOrdersOpened(SOrderInfo &arr[1], int magicnumber=0, string comment=NULL){
   
   ArrayResize(arr,OrdersTotal());
   for(int i=OrdersTotal()-1; i >=0; i--) // loop thru opened order
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)){ //select the order
         if(
            (  OrderMagicNumber()==magicnumber
            || OrderComment()==comment )
         && OrderType() == mOrderType // only opened tickets get passed
         )
		   {    
         FillOrderData(arr[i]);
         Print(__FUNCTION__" Type pass on is", arr[i].Type);
         }
      }
	}
	GetGridStats();   
}

void  CGridMaster::GetOrdersHistory(SOrderInfo &arr[1], int magicnumber=0,string comment=NULL){
   ArrayResize(arr,OrdersHistoryTotal());
   for(int i=OrdersHistoryTotal()-1; i >=0; i--) // loop thru opened order
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){ //select the order
         if(
         (OrderMagicNumber()==magicnumber
         || OrderComment()==comment
		   )
		   && OrderType() == mOrderType
		   )

		 {      //pass order details to SeletedOrder struct if it match the feed-in order ticket 

         FillOrderData(arr[i]);
         }
      }
	}
	GetGridStats();   
}
//---
void CGridMaster::RefillGridWithSavedData(SOrderInfo &arr[1],SOrderInfo_BinFormat &binarr[1])
{
   if(ArraySize(arr) < ArraySize(binarr)) ArrayResize(arr,ArraySize(binarr));
   
   //--- load data
   for(int i=0;i<ArraySize(arr);i++)
     {
      SetOrderToGrid(arr[i],binarr[i].Ticket,MODE_TRADES);
     }
   GetGridSize();    //Update gridsize
}

int  CGridMaster::SetOrderToGrid(SOrderInfo &gridpos, int ordetic, int pool=MODE_TRADES)                    //fill all order details from the input orderticket
{
   if(pool == MODE_TRADES)
     {
      for(int i=OrdersTotal()-1; i >=0; i--) // loop thru opened order
      {
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)){ //select the order
            if(OrderTicket() == ordetic)
              {
               FillOrderData(gridpos);
               return(1);
              } 
         }
      }
     }
   
   else if(pool == MODE_HISTORY)
     {
      for(int i=OrdersHistoryTotal()-1; i >=0; i--) // loop thru opened order
      {
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){ //select the order
            if(OrderTicket() == ordetic)
              {
               FillOrderData(gridpos);
               return(1);
              } 
         }
      }
     }
  return(0);
}


//---
void CGridMaster::RemoveOrderFromGrid(SOrderInfo &mastergrid[1], CTradeInfo &trade, int ordertic){
   
   int iPosRemove;                                // the index that will be remove from mastergrid
   for(int i=ArraySize(mastergrid)-1;i>=0;i--)
       {
         if(mastergrid[i].Ticket = ordertic) {iPosRemove = i; break;}  else continue;
       }
   RemoveIndexFromArray(mastergrid, iPosRemove);
}

//---

int CGridMaster::GetSubGridOrders(SSubGrid &subgrid, int gridsize, int orderstostartddreduce){
      int toptomid_dist = 0;                       // distance between top and middle order
       if(gridsize > 3 && gridsize <7)
         toptomid_dist = 2;
       else if (gridsize>=7 && gridsize <10)
           {
            toptomid_dist = 3;   
           } else{
            toptomid_dist = 4;
           }
      GetGridSize();
      
      //--- get pos and orders from master grid
                 
      if(gridsize <= 3)
        {
         //Print(__FILE__ ": Grid does not have enough orders to start DD reduce" );
         return(false);
        }
        else if(gridsize<orderstostartddreduce)
               {
               //Print(__FILE__ ": Grid not yet reaching required level for DD reduce" );
               return(false); 
               }
               
               else
               {
               subgrid.TopOrderPos= gridsize-1;
               subgrid.MidOrderPos = subgrid.TopOrderPos-toptomid_dist;
               subgrid.BottomOrderPos = 0; 
               if(mOrders[subgrid.BottomOrderPos].Type == mOrderType)
                 {
               //PrintFormat("subgrid.TopOrderPos: %d", subgrid.TopOrderPos);  
               subgrid.TopOrder = mOrders[subgrid.TopOrderPos];
               subgrid.MidOrder = mOrders[subgrid.MidOrderPos];
               subgrid.BottomOrder = mOrders[subgrid.BottomOrderPos];
               }
               //---calculate sub-grid profit: take into account Profit + Swap + Commission
               subgrid.Profit = mOrders[subgrid.TopOrderPos].Profit + mOrders[subgrid.TopOrderPos].Swap + mOrders[subgrid.TopOrderPos].Commission 
                              + mOrders[subgrid.MidOrderPos].Profit + mOrders[subgrid.MidOrderPos].Swap + mOrders[subgrid.MidOrderPos].Commission 
                              + mOrders[subgrid.BottomOrderPos].Profit + mOrders[subgrid.BottomOrderPos].Swap + mOrders[subgrid.BottomOrderPos].Commission
                              ;
               return (true);
           
               }
     return(false);        
}
//---
void CGridMaster::CloseSubGrid(SSubGrid &subgrid, double profittoclose){
   int count = OrdersTotal();
   
   if(subgrid.Profit > profittoclose)
     {     
         for(int i=count-1;i>=0;i--)
           {
           if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
             {
              //---Cloe Top order, pass to PrevClosedTopOrder and reset data
              if(OrderTicket() == subgrid.TopOrder.Ticket 
                 &&  OrderMagicNumber() == mMagicNumber
                  )
                {
                  subgrid.PrevClosedTopOrder = subgrid.TopOrder;
                  if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0)){ResetOrderData(subgrid.TopOrder); subgrid.TopOrderPos=0;};
                }
              //---  
              if(OrderTicket() == subgrid.BottomOrder.Ticket 
                 &&  OrderMagicNumber() == mMagicNumber
                  )
                {
                  if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0)){ResetOrderData(subgrid.BottomOrder); subgrid.BottomOrderPos=0;};
                }
              //---
              
              if(OrderTicket() == subgrid.MidOrder.Ticket 
                 &&  OrderMagicNumber() == mMagicNumber
                  )
                {
                  if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0)){ResetOrderData(subgrid.MidOrder); subgrid.MidOrderPos=0;};
                }  
             }
           }
      //Update MasterGrid Orders[] to reflect the updated master grid:
         GetOrdersOpened(mOrders,mOrderType,mMagicNumber);
         GetGridStats();
    }
}
//---



//---
void CGridMaster::ShowGridOrdersOnChart(CDashboard &dashboard ,SOrderInfo &orders[1], int _headerrowstoskip){
   
      //check GridOrderSize and remove any null row
      int datarowscount = dashboard.GetRowsCount()-_headerrowstoskip;      //get the data rows count
      if(datarowscount > ArraySize(orders) )
        {
         for(int i=dashboard.mRowsCount-1;i>=ArraySize(orders);i--)
           {
      		   dashboard.SetRowText(i, "");
           }
        }   
              
      //---

      dashboard.SetRowText(1,StringFormat("GridProfit: %.2f, MaxLot: %.2f, MinLot: %.2f, GridSize: %d, LatestOpenedAt: %s ",mProfit, mMaxLotSize,mMinLotSize, mSize ));
      dashboard.SetRowText(2,StringFormat("LatestOpenedAt: %s, SubGridProfit: %.2f",TimeToStr(mLatestTradeOpenedTime), mSubGrid.Profit));
      dashboard.SetRowText(3,"Ticket   Symbol   Type   LotSize   OpenPrice   Profit ");
      //--- update row text
      for(int x=0;x<ArraySize(orders);x++)
		  {
		   PrintFormat("---current type is %d", orders[x].Type);
		   dashboard.SetRowText(x+_headerrowstoskip+1, 
		                                 StringFormat("%d  %s   %s       %.2f      %.4f     %.2f " 
		                                               ,orders[x].Ticket
		                                               ,orders[x].Symbol
		                                               ,OrderTypeName(orders[x].Type)
		                                               ,orders[x].Lots
		                                               ,orders[x].OpenPrice
		                                               ,orders[x].Profit
		                                                )
		                                                );
		   }
		dashboard.SetRowText(ArraySize(orders)+_headerrowstoskip+1,StringFormat("LatestOpenedAt: %s ",TimeToStr(mLatestTradeOpenedTime)));
		//realign row    
		dashboard.RealignRows(dashboard);   

}
//void  RealignRows(CDashboard &dashboard, int getydist=50, int setydist=15, int rowgap=5){dashboard.}   

void CGridMaster::ShowGridOrdersOnChart(CDashboard &dashboard ,SSubGrid &subgrid, int _headerrowstoskip){
   
      
		if (dashboard.GetYDistance()>50) {
			dashboard.SetYDistance(15);
		} else {
			dashboard.SetYDistance(dashboard.GetYDistance()+5);
		}
		//---

      dashboard.SetRowText(1,StringFormat("IsGridBeingRescued: %s", (string)mIsRecovering));
      //BottomOrder
	   dashboard.SetRowText(_headerrowstoskip+1, 
	                                 StringFormat("%d  %s   %s       %.2f      %.4f     %.2f " 
	                                               ,subgrid.BottomOrder.Ticket
	                                               ,subgrid.BottomOrder.Symbol
	                                               ,OrderTypeName(subgrid.BottomOrder.Type)
	                                               ,subgrid.BottomOrder.Lots
	                                               ,subgrid.BottomOrder.OpenPrice
	                                               ,subgrid.BottomOrder.Profit
	                                                )
	                                                );
	   //MidOrder
	   dashboard.SetRowText(_headerrowstoskip+2, 
                           StringFormat("%d  %s   %s       %.2f      %.4f     %.2f " 
                                         ,subgrid.MidOrder.Ticket
                                         ,subgrid.MidOrder.Symbol
                                         ,OrderTypeName(subgrid.MidOrder.Type)
                                         ,subgrid.MidOrder.Lots
                                         ,subgrid.MidOrder.OpenPrice
                                         ,subgrid.MidOrder.Profit
                                          )
                                          );
      //TopOrder                                       
	   dashboard.SetRowText(_headerrowstoskip+3, 
                           StringFormat("%d  %s   %s       %.2f      %.4f     %.2f " 
                                         ,subgrid.TopOrder.Ticket
                                         ,subgrid.TopOrder.Symbol
                                         ,OrderTypeName(subgrid.TopOrder.Type)
                                         ,subgrid.TopOrder.Lots
                                         ,subgrid.TopOrder.OpenPrice
                                         ,subgrid.TopOrder.Profit
                                          )
                                          );
   		//realign row    
		//dashboard.RealignRows(dashboard);                                                                                                                              
		   
}  


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
     


        