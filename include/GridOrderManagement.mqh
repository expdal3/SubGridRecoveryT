//--- includes
#include <Blues/UtilityFunctions.mqh>
#include <Blues/TradeInfoClass.mqh>

//---Loggings
#include "GridDashboard.mqh"
#define  _2NODE    0
#define  _3NODE    1

enum ENUM_BLUES_SUBGRID_MODE_SCHEME
  {
   _default_,
   _3node_only_,
   _2node_for_less_than_7_orders_,
   _2node_for_less_than_10_orders_,
   _iteration_based_,
  };

//---structs
struct SSubGrid{                                            // Sub-grid structure to hold sub-grid orders and its metadata
   SOrderInfo                          BottomOrder;            //  deepest DD order-small lotsize
   SOrderInfo                          MidOrder;               //  middle DD order of the grid - medium size lotsize in MasterGrid
   SOrderInfo                          TopOrder;               // Top order of the sub-grid - currently largest size of the MasterGrid 
   int                                 BottomOrderPos;
   int                                 MidOrderPos;
   int                                 TopOrderPos;
   SOrderInfo                          PrevClosedTopOrder;     // (trailing) the latest closed top order : this can be used for Order Replacement Feature
   double                              Profit;                 // Sum of profit for the sub-grid
   int                                 TopToMidStep;             //Step of pos between Top and mid order
};

struct SIteration
  {
   string   Input;
   int      Mode;
   double   ProfitToClose;
  };

struct SPanicClose
  {
   SOrderInfo  TopOrder;
   SOrderInfo  SecondOrder;
   bool        OrderCount;
   bool        Drawdown;
   bool        LotSize;
   double      Profit;                 // Sum of profit for the sub-grid
   int         Iteration;
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
   bool                 mIsRecovering;                // True/false, status of grid being recovered or not
   int                  mRescueMode;                  // Mode = 2Node or 3Node

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
      string      mGridName;                  //unique grid name - combination of symbol and magicnumber
      string      mSymbol;
      int         mLevelStartRescue;         //Grid level that trigger DD reduce
      double      mProfitToClose;               // Tracking current profit to close;   
      int         mOrderType;
      int         mMagicNumber;
      string      mOrderComment;
      ENUM_BLUES_SUBGRID_MODE_SCHEME      mRescueScheme;             // default / 2nodeswhenlessthan7order / 2nodeswhenlessthan10orders
      bool        mIsNewGrid;
      int         mSymbolMagicTypeOrdersTotal;                       // Count of a combination of symbol-magic-ordertype
      
      //---Dashboard object
      CGridDashboard  *mMasterInfo;
      CGridDashboard  *mSubInfo;
      
      //---PanicClose input
      SPanicClose       mPanicClose;
      double            mPanicCloseDrawDownTrigger;           //level of Drawdown to trigger PanicClose
      double            mPanicCloseMaxLotSizeTrigger;         //MaxLotSize to trigger PanicClose
      int               mPanicCloseOrderCountTrigger;           // number of order in the grid to trigger PanicClose
      int               mPanicCloseSecondOrderPos;
      int               mPanicCloseNStop;

      double            mPanicCloseProfitToClose;
      bool              mIsPanic;                        //track the PanicClose status 
              
      //---Iteration-rescue attributes
public:           
   SIteration           mIterations[];                // hold the settings for all iteration #1 - #10 to be used in the GetIterationModeAndProfit()
   int                  mIteration;                   // hold the current iteration of the main grid, starting value=1
   int                  mRescueCount;                 // track the total number of rescue - for telemetry  
   double               mIterationProfitToClose;      
protected:
   string               mIterationInputStringList;    // hold user's input mode and profitToClose string list   
   string               mIterationInputStrings[];           // hold list of Mode:ProfitToClose string pair


public:
                  CGridMaster(){Init();};
                  CGridMaster(string symbol, int magicnumber, int ordertype,int levelstartrescue, ENUM_BLUES_SUBGRID_MODE_SCHEME rescuescheme, double profittoclose, string iterationinput, string comment )
                                          :mSymbol(symbol)
                                          ,mMagicNumber(magicnumber)
                                          ,mOrderType(ordertype)
                                          ,mLevelStartRescue(levelstartrescue)
                                          ,mRescueScheme(rescuescheme)
                                          ,mProfitToClose(profittoclose)
                                          ,mIterationInputStringList(iterationinput)
                                          ,mOrderComment(comment){Init();};
                  ~CGridMaster();
      //---
      int         Init();
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
      virtual void  GetOrdersOpened(); //SOrderInfo &arr[1]
      virtual void  GetOrdersHistory(); 
      virtual int   SetOrderToGrid(SOrderInfo &gridpos, int ordetic, int pool=MODE_TRADES);                    //fill all order details from the input orderticket
      virtual void  RefillGridWithSavedData(SOrderInfo &arr[1], SOrderInfo_BinFormat &binarr[1] );
      
      //---       read orders to Sub grid
      int         GetSubGridOrders();
      
      //---       orders removal
      void        RemoveOrderTicketFromGrid(int ordertic);            //remove an order from grid and shiftup using an order ticket

      
      //---       Profit & stats calculation
      void        GetGridStats();                                                                              //Get the latest Grid's stats: profit, min/maxlotsize, latest trade opened, IsRecovering status, 
      int         GetGridSize(){mSize = ArraySize(mOrders);return(mSize);};
      double      GetProfit();
      double      GetMaxLotSize();
      double      GetMinLotSize();
      int         GetLatestTradeOpenedTime();
      bool        GetState(SSubGrid &subgrid);
      
      //---       Orders close
      int         CloseSubGrid(SSubGrid &subgrid);
      bool        IsNewGrid(){if((ArraySize(mOrders)<=1 && mSize>1)
                                 || (mMaxLotSize>mMinLotSize && GetMaxLotSize() == GetMinLotSize())
                                 ) 
                                    {mIsNewGrid = true; } else{ mIsNewGrid = false; } return(mIsNewGrid);};                //track if a new grid has just started 
      bool        IsAGridOrderJustClosed();                            //check if an grid order has just be closed - to detect partial close event                                            
      void        RefreshGridAfterClose(){
                        CGridMaster::GetOrdersOpened();
                        GetGridStats();
                        GetSubGridModeAndOrdersPos();                      //refresh the Iteration Mode and ProfitToClose from mIteration
                        ResetOrderData(mSubGrid.MidOrder);                 // reset Subgrid midOrder in case switching from 3Node back to 2Node
                        GetSubGridOrders();
         };
      
      //---       PanicClose
      void         GetPanicCloseParameters(int ordercount, double maxdd, double maxlotsize, double profittoclose, int secondpos, double nstop){
                                    mPanicCloseOrderCountTrigger = ordercount;
                                    mPanicCloseDrawDownTrigger = maxdd;
                                    mPanicCloseMaxLotSizeTrigger = maxlotsize;
                                    mPanicCloseProfitToClose = profittoclose;
                                    mPanicCloseSecondOrderPos = secondpos;
                                    mPanicCloseNStop = nstop;
                                    };
      bool        IsPanicClose();                                    // check if one or more of the PanicClose condition is true
      int         ClosePanicCloseOrders();
      int         GetPanicCloseOrders(int secondorderpos=0);
      
      //---       Orders symbol - magic - type count
      int         GetSymbolMagicTypeOrdersTotal();                   //filter and count combination of Symbol, Magic and OrderType from OrdersTotal
      
      //---       Loggings          
      void        ShowGridOrdersOnChart();
      void        ShowGridOrdersOnChart(SSubGrid &subgrid);
protected:
      int         SetCornerForGridDashboard(int ordertype);

protected:
      void        ResetSubGridOrders(SSubGrid &subgrid){ResetOrderData(subgrid.BottomOrder);
                                                        ResetOrderData(subgrid.MidOrder);
                                                        ResetOrderData(subgrid.TopOrder);
                                                         subgrid.Profit=0;
                                                      };            //remove an order from grid and shiftup using an order ticket
      void        GetSubGridModeAndOrdersPos();                                                                 // determine current subgrid mode: 2Node or 3Node base on GridSize                                                 
      //---       Iteration-base rescue
      int         ReadInputIterationModeAndProfit();
public:
      void        GetIterationModeAndProfit();
       
};

int  CGridMaster::Init(){
      ResetOrderData(mSubGrid.BottomOrder);
      ResetOrderData(mSubGrid.MidOrder);
      ResetOrderData(mSubGrid.TopOrder);
      
      mSubGrid.BottomOrderPos=0;
      mSubGrid.MidOrderPos=0;
      mSubGrid.TopOrderPos=0;
         
      mGridName = mSymbol+IntegerToString(mMagicNumber);
      mSymbolMagicTypeOrdersTotal = GetSymbolMagicTypeOrdersTotal();
      
      ArrayResize(mIterations,10);
      mIteration = 1;         // init mIteration with 1
      mIsRecovering=false;    //initialize mIsRecovery status - set to false
      ReadInputIterationModeAndProfit();
      
      
      //retrieve grid info onInit
      GetOrdersOpened();
      GetSubGridOrders();
      GetGridStats();
      //Init dashboard object:
      //---inputs for dashboard logggings when OneChartSetUp=false (OnePair)
      
      //mMasterInfo = new CDashboard(OrderTypeName(mOrderType)+"MasterGridDB",SetCornerForGridDashboard(mOrderType),400,15);
      //mSubInfo = new CDashboard(OrderTypeName(mOrderType)+"SubGridDB",SetCornerForGridDashboard(mOrderType),3,15);

      mMasterInfo = new CGridDashboard(OrderTypeName(mOrderType)+"MasterGridDB",SetCornerForGridDashboard(mOrderType),400,15,15,4);
      mSubInfo = new CGridDashboard(OrderTypeName(mOrderType)+"SubGridDB",SetCornerForGridDashboard(mOrderType),3,15,15,3);
      PrintFormat(__FUNCTION__+": Initialize successfully Grid Symbol: %s magic %d", mSymbol, mMagicNumber);

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
   PrintFormat(__FUNCTION__+": PanicOrderCount %d, CurrentSize %d, %s",mPanicCloseOrderCountTrigger, mSize, (string)IsPanicClose());
   //GetSubGridModeAndOrdersPos();
   //GetIterationModeAndProfit();
   
}

double CGridMaster::GetProfit()
{  
   double profit = 0.0;
   for(int i=0;i<ArraySize(mOrders);i++){
      if(OrderSelect(mOrders[i].Ticket,SELECT_BY_TICKET,MODE_TRADES)) 
      {mOrders[i].Profit = OrderProfit();
      profit += mOrders[i].Profit;
      }
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
   if(mSize>=mLevelStartRescue) mIsRecovering = true;
   else mIsRecovering = false;
   return (mIsRecovering);
}

//---

void  CGridMaster::GetOrdersOpened(){

   //---Go through the list of orders and filter out only those order ticket that match the OrderType
   ArrayResize(mOrders,1);
   for(int i=0; i <=OrdersTotal()-1; i++) // loop thru opened order
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)){ //select the order
         if(
            (  
            OrderSymbol()==mSymbol
            && OrderMagicNumber()==mMagicNumber
            && OrderType() == mOrderType     // only opened tickets get passed
            //|| StringFind(OrderComment(),mOrderComment)
            )
         )
		   {    
         FillOrderData(mOrders[0]);       //insert the Order's data at pos 0 of mOrders
         InsertIndexToArray(mOrders);     //shift all order data to the left, and add one slot
         ResetOrderData(mOrders[0]);   
         }
      }
	}
	RemoveIndexFromArray(mOrders,0);
	//check if it is a new grid, then reset mIteration to 1
	if (IsNewGrid()){
	   mIteration = 1;
	   mIsNewGrid = false;                 //revert back to false
	};
	GetGridStats();   
}

void  CGridMaster::GetOrdersHistory(){
   ArrayResize(mOrders,OrdersHistoryTotal());
   for(int i=OrdersHistoryTotal()-1; i >=0; i--) // loop thru opened order
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){ //select the order
         if(
         (
         OrderSymbol()==mSymbol
         && OrderMagicNumber()==mMagicNumber
         && OrderType() == mOrderType
         //|| StringFind(OrderComment(),mOrderComment)
		   )

		   )

		 {      //pass order details to SeletedOrder struct if it match the feed-in order ticket 

         FillOrderData(mOrders[i]);
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
void CGridMaster::RemoveOrderTicketFromGrid(int ordertic){
   
   int iPosRemove;                                // the index that will be remove from mastergrid
   for(int i=ArraySize(mOrders)-1;i>=0;i--)
       {
         if(mOrders[i].Ticket = ordertic) {iPosRemove = i; break;}  else continue;
       }
   RemoveIndexFromArray(mOrders, iPosRemove);
}


//---



int CGridMaster::GetSubGridOrders(){
      GetGridSize();
      GetSubGridModeAndOrdersPos();                //determine: ModeScheme, current Mode (2Node or 3Node), and TopToMidStep
      #ifdef _DEBUG
      PrintFormat(__FUNCTION__+": current mode is %s", RescueModeToString(mRescueMode));           
      #endif
      if(mSize < 3)                                //set minimum to be at least 3 orders
        {
         //Print(__FILE__ ": Grid does not have enough orders to start DD reduce" );
         ResetSubGridOrders(mSubGrid);
         return(false);
        }
        else if(mSize<mLevelStartRescue)
               {
               //Print(__FILE__ ": Grid not yet reaching required level for DD reduce" );
               ResetSubGridOrders(mSubGrid);
               return(false); 
               }
            else{
            if(mOrders[mSubGrid.BottomOrderPos].Type == mOrderType && mIsRecovering==true)              //make sure only fetch subgrid order when mIsRecovering = true
            {
               if(mRescueScheme==_3node_only_ && mSize<=4) return(false);
               else{

                     switch(mRescueMode)
                       {
                        case _2NODE :
                           mSubGrid.TopOrder = mOrders[mSubGrid.TopOrderPos];
                           mSubGrid.BottomOrder = mOrders[mSubGrid.BottomOrderPos];
                           ResetOrderData(mSubGrid.MidOrder);   
                          break;
                        case _3NODE :
                           mSubGrid.TopOrder = mOrders[mSubGrid.TopOrderPos];
                           mSubGrid.MidOrder = mOrders[mSubGrid.MidOrderPos];
                           mSubGrid.BottomOrder = mOrders[mSubGrid.BottomOrderPos];
                          break;  
                        default:
                          break;
                       }
               //PrintFormat("subgrid.TopOrderPos: %d", subgrid.TopOrderPos);  
               }
               //---calculate sub-grid profit: take into account Profit + Swap + Commission
               if(mIsRecovering==false) mSubGrid.Profit = 0;                                  //reset subgrid's profit
               else{
                     switch(mRescueMode)
                       {
                        case _2NODE :
                     mSubGrid.Profit = mOrders[mSubGrid.TopOrderPos].Profit + mOrders[mSubGrid.TopOrderPos].Swap + mOrders[mSubGrid.TopOrderPos].Commission  
                           + mOrders[mSubGrid.BottomOrderPos].Profit + mOrders[mSubGrid.BottomOrderPos].Swap + mOrders[mSubGrid.BottomOrderPos].Commission
                           ;
                         break;
                        case _3NODE :
                     mSubGrid.Profit = mOrders[mSubGrid.TopOrderPos].Profit + mOrders[mSubGrid.TopOrderPos].Swap + mOrders[mSubGrid.TopOrderPos].Commission 
                           + mOrders[mSubGrid.MidOrderPos].Profit + mOrders[mSubGrid.MidOrderPos].Swap + mOrders[mSubGrid.MidOrderPos].Commission 
                           + mOrders[mSubGrid.BottomOrderPos].Profit + mOrders[mSubGrid.BottomOrderPos].Swap + mOrders[mSubGrid.BottomOrderPos].Commission
                           ;
                          break;  
                        default:
                          break;
                       }
               }
            return (true);
               }
               }  

     return(false);        
}
//---
int CGridMaster::CloseSubGrid(SSubGrid &subgrid){
   int count = OrdersTotal();
   int closecount = 0;
   bool isclosed = false;
    
   //handle iteration-base rescue switch---

   double profittoclose = (mRescueScheme==_iteration_based_)? mIterationProfitToClose : mProfitToClose;
     
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
                  if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0)){ResetOrderData(subgrid.TopOrder); subgrid.TopOrderPos=0; closecount++;}
                }
              //---  
              if(OrderTicket() == subgrid.BottomOrder.Ticket 
                 &&  OrderMagicNumber() == mMagicNumber
                  )
                {
                  if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0)){ResetOrderData(subgrid.BottomOrder); subgrid.BottomOrderPos=0;closecount++;}
                }
              //---
              
              if(OrderTicket() == subgrid.MidOrder.Ticket 
                 &&  OrderMagicNumber() == mMagicNumber
                 && mRescueMode == _3NODE
                  )
                {
                  if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0)){ResetOrderData(subgrid.MidOrder); subgrid.MidOrderPos=0;closecount++;}
                }  
             }
           }
           
        //GetSubGridModeAndOrdersPos();                       //get the latest mRescueMode
        if( 
            closecount >=2            
            )
          {
            isclosed = true;
            closecount = 0;
          }   
      //Update MasterGrid Orders[] to reflect the updated master grid:
         RefreshGridAfterClose();
         

   }
   return (isclosed);
}
//---



//---
void CGridMaster::ShowGridOrdersOnChart(){
      double profittoclose = (mRescueScheme==_iteration_based_)? mIterationProfitToClose : mProfitToClose;
      int _headerrowstoskip = mMasterInfo.mHeaderRowsToSkip;
      //check GridOrderSize and remove any null row
      int datarowscount = mMasterInfo.mDashboard.GetRowsCount()-_headerrowstoskip;      //get the data rows count
      if(datarowscount > ArraySize(mOrders) )
        {
         for(int i=mMasterInfo.mDashboard.mRowsCount-1;i>=ArraySize(mOrders);i--)
           {
      		   mMasterInfo.mDashboard.SetRowText(i, "");
           }
        }   
              
      //---
      mMasterInfo.mDashboard.SetRowText(0,mMasterInfo.mTableHeaderTxt);
      mMasterInfo.mDashboard.SetRowText(1,StringFormat("GridProfit: %.2f, MaxLot: %.2f, MinLot: %.2f, GridSize: %d",mProfit, mMaxLotSize,mMinLotSize, mSize ));
      mMasterInfo.mDashboard.SetRowText(2,StringFormat("SubGridProfit (Target): %.2f | (%.2f)", mSubGrid.Profit,profittoclose));
      mMasterInfo.mDashboard.SetRowText(3,mMasterInfo.mColHeaderTxt);
      //--- update row text
      for(int x=0;x<ArraySize(mOrders);x++)
		  {
		   mMasterInfo.mDashboard.SetRowText(x+_headerrowstoskip+1, 
		                                 StringFormat("%d  %s   %s       %.2f      %.4f     %.2f " 
		                                               ,mOrders[x].Ticket
		                                               ,mOrders[x].Symbol
		                                               ,OrderTypeName(mOrders[x].Type)
		                                               ,mOrders[x].Lots
		                                               ,mOrders[x].OpenPrice
		                                               ,mOrders[x].Profit
		                                                )
		                                                );
		   }
		if(mLatestTradeOpenedTime!=0)mMasterInfo.mDashboard.SetRowText(ArraySize(mOrders)+_headerrowstoskip+1,StringFormat("LatestOpenedAt: %s ",TimeToStr(mLatestTradeOpenedTime)));
		if(mIsPanic)mMasterInfo.mDashboard.SetRowText(ArraySize(mOrders)+_headerrowstoskip+2,StringFormat("PANIC!!! PanicProft: %.2f | %d times",mPanicClose.Profit,mPanicClose.Iteration));
		//realign row    
		//dashboard.RealignRows(dashboard);   

}

void CGridMaster::ShowGridOrdersOnChart(SSubGrid &subgrid){
      
      int _headerrowstoskip = mSubInfo.mHeaderRowsToSkip;
      string blank = "----";
      mSubInfo.mDashboard.SetRowText(1,StringFormat("Rescueing?:%s, Mode: %s | Iteration: %d" , (string)mIsRecovering, RescueModeToString(mRescueMode), mIteration));

      if(subgrid.BottomOrder.Ticket!=0)
        {
	   mSubInfo.mDashboard.SetRowText(_headerrowstoskip+1, 
	                                 StringFormat("%d  %s   %s       %.2f      %.4f     %.2f " 
	                                               ,subgrid.BottomOrder.Ticket
	                                               ,subgrid.BottomOrder.Symbol
	                                               ,OrderTypeName(subgrid.BottomOrder.Type)
	                                               ,subgrid.BottomOrder.Lots
	                                               ,subgrid.BottomOrder.OpenPrice
	                                               ,subgrid.BottomOrder.Profit
	                                                )
	                                                );
        } else{
       mSubInfo.mDashboard.SetRowText(_headerrowstoskip+1, 
	                                 StringFormat("%d  %s   %s       %s      %s     %s " 
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                                )
	                                                );
        
        }

	   //MidOrder
      if(subgrid.MidOrder.Ticket!=0)
        {
        	   mSubInfo.mDashboard.SetRowText(_headerrowstoskip+2, 
                           StringFormat("%d  %s   %s       %.2f      %.4f     %.2f " 
                                         ,subgrid.MidOrder.Ticket
                                         ,subgrid.MidOrder.Symbol
                                         ,OrderTypeName(subgrid.MidOrder.Type)
                                         ,subgrid.MidOrder.Lots
                                         ,subgrid.MidOrder.OpenPrice
                                         ,subgrid.MidOrder.Profit
                                          )
                                          );
        }else{
       mSubInfo.mDashboard.SetRowText(_headerrowstoskip+2, 
	                                 StringFormat("%d  %s   %s       %s      %s     %s " 
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                                )
	                                                );
      }
      //TopOrder
      if(subgrid.TopOrder.Ticket!=0)
        {
        	   mSubInfo.mDashboard.SetRowText(_headerrowstoskip+3, 
                           StringFormat("%d  %s   %s       %.2f      %.4f     %.2f " 
                                         ,subgrid.TopOrder.Ticket
                                         ,subgrid.TopOrder.Symbol
                                         ,OrderTypeName(subgrid.TopOrder.Type)
                                         ,subgrid.TopOrder.Lots
                                         ,subgrid.TopOrder.OpenPrice
                                         ,subgrid.TopOrder.Profit
                                          )
                                          );
        }else{
         mSubInfo.mDashboard.SetRowText(_headerrowstoskip+3, 
	                                 StringFormat("%d  %s   %s       %s      %s     %s " 
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                                )
	                                                );
        }
                                          
      mSubInfo.mDashboard.SetRowText(8,"-----------------------------------");
      mSubInfo.mDashboard.SetRowText(9,StringFormat("Scheme: %s" , RescueSchemeToString(mRescueScheme)));
      mSubInfo.mDashboard.SetRowText(10,StringFormat(" %d subgrids has been closed" , mRescueCount));                                       
                                                                                                                          	   

}
//---

void        CGridMaster::GetSubGridModeAndOrdersPos()
{
                
   switch(mRescueScheme)
     {
      case  _default_:
            if(mSize<=4){
            mRescueMode=_2NODE;
            mSubGrid.TopToMidStep = 0;
            }
         else if(mSize<7){
            mRescueMode=_3NODE;
            mSubGrid.TopToMidStep = 2;
         }else if(mSize<10){
            mRescueMode=_3NODE;
            mSubGrid.TopToMidStep = 3;
          }else{
            mRescueMode=_3NODE;
            mSubGrid.TopToMidStep = 4;
          }
        break;
      case  _3node_only_:
            if(mSize<=4){
            mRescueMode=_3NODE;
            mSubGrid.TopToMidStep = 1;
            }
         else if(mSize<7){
            mRescueMode=_3NODE;
            mSubGrid.TopToMidStep = 2;
         }else if(mSize<10){
            mRescueMode=_3NODE;
            mSubGrid.TopToMidStep = 3;
          }else{
            mRescueMode=_3NODE;
            mSubGrid.TopToMidStep = 4;
          }
        break;  
      case _2node_for_less_than_7_orders_:
         if(mSize<=4){
            mRescueMode=_2NODE;
            mSubGrid.TopToMidStep = 0;
            }
         else if(mSize<7){
            mRescueMode=_2NODE;
            mSubGrid.TopToMidStep = 0;
         }else if(mSize<10){
            mRescueMode=_3NODE;
            mSubGrid.TopToMidStep = 3;
          }else{
            mRescueMode=_3NODE;
            mSubGrid.TopToMidStep = 4;
          }
         break;
      case _2node_for_less_than_10_orders_:
         if(mSize<=4){
            mRescueMode=_2NODE;
            mSubGrid.TopToMidStep = 0;
            }
         else if(mSize<7){
            mRescueMode=_2NODE;
            mSubGrid.TopToMidStep = 0;
         }else if(mSize<10){
            mRescueMode=_2NODE;
            mSubGrid.TopToMidStep = 0;
          }else{
            mRescueMode=_3NODE;
            mSubGrid.TopToMidStep = 4;
          }
         break;
      case _iteration_based_:
         GetIterationModeAndProfit();                       //run to get mRescueMode and mIterationProfitToClose
         #ifdef _DEBUG PrintFormat(__FUNCTION__+": Current iteration Mode is %s, profitToClose is %.2f",RescueModeToString(mRescueMode),mIterationProfitToClose); #endif
         if(mRescueMode==_2NODE) mSubGrid.TopToMidStep = 0;
         else if(mRescueMode==_3NODE)
           {
            if(mSize<=4){
            mSubGrid.TopToMidStep = 1;
            }
            else if(mSize<7){
            mSubGrid.TopToMidStep = 2;
            }else if(mSize<10){
            mSubGrid.TopToMidStep = 3;
            }else{
            mSubGrid.TopToMidStep = 4;
            }
           }
         break;            
      default:
         break;
     }
   // set SubGrid's orderpos
   mSubGrid.TopOrderPos = mSize-1;
   mSubGrid.MidOrderPos = mSubGrid.TopOrderPos-mSubGrid.TopToMidStep;
   mSubGrid.BottomOrderPos = 0;  

}  
//---Iteration-base rescue

int   CGridMaster::ReadInputIterationModeAndProfit(){
   int sep_pos;
   if(StringSplitToArray(mIterationInputStrings, mIterationInputStringList,",")>0){
      ArrayResize(mIterations,ArraySize(mIterationInputStrings));
      for(int i=ArraySize(mIterationInputStrings)-1;i>=0;i--)
        {

         mIterations[i].Input = StringTrimRight(StringTrimLeft(mIterationInputStrings[i]));             //pass in the text input, make sure no trailing blank
         
         sep_pos = StringFind(mIterations[i].Input,":");
         if(sep_pos>=0){
            mIterations[i].Mode = StringToInteger(StringSubstr(mIterations[i].Input,0,sep_pos));
            mIterations[i].ProfitToClose = StringToDouble(StringSubstr(mIterations[i].Input,sep_pos+1));
         #ifdef _DEBUG   
            PrintFormat(__FUNCTION__+": mIterations[%d].Mode = %s, ProfitToClose = %.2f", i, RescueModeToString(IntToRescueMode(mIterations[i].Mode)),mIterations[i].ProfitToClose);
         #endif
         }
        }
   }
   return(0);
}

void CGridMaster::GetIterationModeAndProfit()
{
        mRescueMode = IntToRescueMode(mIterations[mIteration-1].Mode);
        mIterationProfitToClose = mIterations[mIteration-1].ProfitToClose;
}

int   CGridMaster::GetSymbolMagicTypeOrdersTotal()
{
   int count=0;
   for(int i=0;i<OrdersTotal();i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(mSymbol==OrderSymbol()                    // NOTE: Suffix has bee added in CGridCollection::ReadSymbolStringList
            && mMagicNumber==OrderMagicNumber()
            && mOrderType==OrderType()
            )                             
           {
            count++;
           }
        }
     }
   
   return (count);
}

int  CGridMaster::SetCornerForGridDashboard(int ordertype){
         int corner;
         if(ordertype==OP_BUY)   corner = CORNER_RIGHT_UPPER; else corner = CORNER_RIGHT_LOWER;
         return (corner);
}

bool CGridMaster::IsAGridOrderJustClosed()
{
   int count = ArraySize(mOrders);
   bool justclosed = false;
   for(int i=0;i<=count-1;i++)
     {
      if(mOrders[i].Ticket!=0 && GetInfoIfOpened(mOrders[i].Ticket)==0) {justclosed = true; break;}         //search the ticket thu the list of open orders can cannot found 
      else continue; 
     }
   return(justclosed);  
}

int CGridMaster::ClosePanicCloseOrders()
{  
   int closecount = 0;
   if(mIsPanic == true)
     {
       if(mSize <= 3 || mPanicClose.Iteration > mPanicCloseNStop) return(0);
       else{
          if(mPanicClose.Profit>= mPanicCloseProfitToClose)
            {
               if(OrderSelect(mPanicClose.TopOrder.Ticket, SELECT_BY_TICKET, MODE_TRADES))
                  {if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0)){ResetOrderData(mPanicClose.TopOrder); closecount++;}
                  }
               if(OrderSelect(mPanicClose.SecondOrder.Ticket, SELECT_BY_TICKET, MODE_TRADES))
                  {if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0)){ResetOrderData(mPanicClose.SecondOrder); closecount++;}
                  }
            }
           }  
     }
   if(closecount >=1) {
   mPanicClose.Iteration++;
   RefreshGridAfterClose(); 
   return(1);
   }
   return(0);   

}

int   CGridMaster::GetPanicCloseOrders(int secondorderpos=0)
{  
   if (secondorderpos>=mSize-1) return(0); 
   if(mIsPanic==true)
     {
      mPanicClose.TopOrder    = mOrders[mSize-1];
      mPanicClose.SecondOrder = mOrders[secondorderpos];
      mPanicClose.Profit      = mOrders[mSize-1].Profit+ mOrders[mSize-1].Swap+ mOrders[mSize-1].Commission
                                +mOrders[secondorderpos].Profit+ mOrders[secondorderpos].Swap+ mOrders[secondorderpos].Commission;
     return(1);
     }
   return(0);
}


bool CGridMaster::IsPanicClose()
{
   bool ispanic = false;
   int triggercount = 0;
   if (mPanicCloseOrderCountTrigger!=0 && mSize >= mPanicCloseOrderCountTrigger) {triggercount++; mPanicClose.OrderCount=true ;}
   if (mPanicCloseDrawDownTrigger!=0 && mProfit <= mPanicCloseDrawDownTrigger) {triggercount++; mPanicClose.Drawdown=true;} 
   if (mPanicCloseMaxLotSizeTrigger!=0 && mMaxLotSize >= mPanicCloseMaxLotSizeTrigger) {triggercount++; mPanicClose.LotSize=true;} 
   
   if(triggercount>=1) ispanic = true;
   mIsPanic = ispanic;
   return (ispanic);

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


int IntToRescueMode(int interger){
   int mode;
   if(interger == 2) mode = _2NODE;
   else if (interger == 3) mode = _3NODE; 
   return (mode);
}

string RescueModeToString(int mode){
   int str="";
   if(mode == _2NODE) str = "2Node";
   else if(mode == _3NODE) str = "3Node";
   return (str);
}

string RescueSchemeToString(ENUM_BLUES_SUBGRID_MODE_SCHEME scheme){
   string str;
   switch(scheme)
     {
      case  _default_:
         str = "default";
        break;
      case  _3node_only_:
         str = "3NodeOnly";
        break;
      case  _2node_for_less_than_7_orders_:
         str = "2NodeFor7OrdersOrLess";
        break;
      case  _2node_for_less_than_10_orders_:
         str = "2NodeFor10OrdersOrLess";
        break;
      case  _iteration_based_:
         str = "Iteration-based";
        break;
      default:
        break;
     }
    return (str);
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
     


        