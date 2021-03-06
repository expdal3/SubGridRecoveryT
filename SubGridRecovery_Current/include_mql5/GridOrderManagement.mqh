//--- includes
#include <Blues/UtilityFunctions.mqh>
#include <Blues/TradeInfoClass.mqh>
#include <Blues/Credentials.mqh>
#include "LogsFunction.mqh"
#include <Orchard/Frameworks/Framework.mqh>  //** remember commented out when compile from the EA level once move to Prod

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
  
enum ENUM_BLUES_CRITCLOSE_PANIC_OPTION
  {
   _1_or_more_panic_reason_,            
   _for_drawdown_or_maxlot_,
   _for_drawdown_only_,
   _for_maxlot_only_,
   _for_drawdown_and_maxlot_,           
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

struct SCritClose{
   CSignalTimeRange*   TimeRange[];          //hold TimeRange info
   string              TimeRangeString;    //hold TimeRange info in String
   SOrderInfo          TopOrder;
   SOrderInfo          BottomOrder;
   double              TopOrderProfit;
   bool                IsEndTimeHasClosed;    //use to run the CritCloseAtEndTime only once for each timerange
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
   double      TrailingProfitToClose;
  };

class CGridBase : public CTradeInfo
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
      bool        mFirstTime;
      bool        mIsOneChartSetup;
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
      long              mPanicCloseRescueCount;
      bool              mPanicCloseIsDriftProfit;
      double            mPanicCloseProfitDriftStep ;
      double            mPanicCloseProfitDriftLimit;
      bool              mIsPanic;                        //track the PanicClose status 
       
      //---TimeCritClose input        
      
      SCritClose        mCritClose;
      string            mCritCloseInputTimeRangeString;
      int               mCritCloseMaxOpenMinute;
      double            mCritProfitToCloseTopOrder;
      bool              mCritForceCloseAtEndTime;                 //if true, close the top and bottom order when at the EndTime if still in panic mode        
      bool              mCritForceCloseAtEndTimeIgnoreDuration;   //if True:ignore BottomOrder's OpenDuration when forceClose
      bool              mIsDuringCritical;
      //bool              mCritCloseAllowed;
      int               mCritCloseRescueCount;
      ENUM_BLUES_CRITCLOSE_PANIC_OPTION mCritClosePanicReason;
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
                  CGridMaster(string symbol, int magicnumber, int ordertype,int levelstartrescue, ENUM_BLUES_SUBGRID_MODE_SCHEME rescuescheme, double profittoclose, string iterationinput, string comment 
                              , bool isOneChartSetup
                              )
                                          :mSymbol(symbol)
                                          ,mMagicNumber(magicnumber)
                                          ,mOrderType(ordertype)
                                          ,mLevelStartRescue(levelstartrescue)
                                          ,mRescueScheme(rescuescheme)
                                          ,mProfitToClose(profittoclose)
                                          ,mIterationInputStringList(iterationinput)
                                          ,mOrderComment(comment)
                                          ,mIsOneChartSetup(isOneChartSetup)
                                          {Init();};
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
      virtual void  RefillGridWithSavedData(SOrderInfo &arr[], SOrderInfo_BinFormat &binarr[] );
      
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
                        //CGridMaster::GetOrdersOpened();
                        //GetGridStats();
                        //GetSubGridModeAndOrdersPos();                      //refresh the Iteration Mode and ProfitToClose from mIteration
                        ResetOrderData(mSubGrid.MidOrder);                 // reset Subgrid midOrder in case switching from 3Node back to 2Node
                        //GetSubGridOrders();
         };
      
      //---       PanicClose
      void         SetPanicCloseParameters(int ordercount, double maxdd, double maxlotsize, double profittoclose, int secondpos, double nstop, bool isdrift, double drifstep, double driftlimit){
                                    mPanicCloseOrderCountTrigger = ordercount;
                                    mPanicCloseDrawDownTrigger = maxdd;
                                    mPanicCloseMaxLotSizeTrigger = maxlotsize;
                                    mPanicCloseProfitToClose = profittoclose;
                                    mPanicCloseSecondOrderPos = secondpos;
                                    mPanicCloseNStop = nstop;
                                    mPanicCloseIsDriftProfit = isdrift;
                                    mPanicCloseProfitDriftStep = drifstep;
                                    mPanicCloseProfitDriftLimit = driftlimit;
                                    };
      bool        IsPanicClose();                                    // check if one or more of the PanicClose condition is true
      int         ClosePanicCloseOrders();
      int         GetPanicCloseOrders(int secondorderpos=0);
      void        GetPanicProfitToClose();
      //---       TimeCritClose
      void        SetCritCloseParameters(ENUM_BLUES_CRITCLOSE_PANIC_OPTION critClosePanicReason, string critCloseInputTimeRangeString, int critCloseMaxOpenMinute, double critProfitToCloseTopOrder, bool critForceCloseAtEndTime, bool critForceCloseIgnoreDuration
                                         //, bool critCloseAllowed 
                                         ){
                        //mCritCloseAllowed = critCloseAllowed;
                        mCritClosePanicReason = critClosePanicReason;
                        mCritCloseInputTimeRangeString = critCloseInputTimeRangeString;
                        mCritCloseMaxOpenMinute = critCloseMaxOpenMinute;
                        mCritProfitToCloseTopOrder = critProfitToCloseTopOrder;
                        mCritForceCloseAtEndTime = critForceCloseAtEndTime;
                        mCritForceCloseAtEndTimeIgnoreDuration = critForceCloseIgnoreDuration;
                        mCritCloseRescueCount = 0;
                        mIsDuringCritical = false;
 
                  };
      
      void        CritSetTimeRange();
      void        SplitHourAndMinute(STime &time, string timestring);
      int         GetCritCloseOrders();
      int         CloseCritCloseOrders();
      bool        IsDuringCritical();
      int         GetCritBottomOrderDuration();
      bool        IsCritAtEndTime();
      void        CritCloseReset();
      bool        CritCheckIfPanicOf();

            
      //---       Orders symbol - magic - type count
      int         GetSymbolMagicTypeOrdersTotal(){int count = CountOrder(mSymbol, mMagicNumber, mOrderType, MODE_TRADES); return(count);};                   //filter and count combination of Symbol, Magic and OrderType from OrdersTotal
      
      //---       Loggings
      void        Setup();          
      void        ShowGridOrdersOnChart();
      void        ShowGridOrdersOnChart(SSubGrid &subgrid);

protected:
      int         SetCornerForGridDashboard(int ordertype);
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
      
      mSubGrid.BottomOrderPos=0;
      mSubGrid.MidOrderPos=0;
      mSubGrid.TopOrderPos=0;
         
      mGridName = mSymbol+IntegerToString(mMagicNumber);
      ArrayResize(mIterations,10);
      mIteration = 1;         // init mIteration with 1
      mIsRecovering=false;    //initialize mIsRecovery status - set to false

      
      //retrieve grid info onInit

      
      //Init Panic Close parameters
      mPanicClose.Iteration = 1;         // init mPanicClose with 1
      mIsPanic = 0;         // init mPanicClose with 1
      mFirstTime = true;
      //Init dashboard object:
      //---inputs for dashboard logggings when OneChartSetUp=false (OnePair)


      PrintFormat(__FUNCTION__+": Initialize successfully %s Grid Symbol: %s magic %d", OrderTypeName(mOrderType),mSymbol, mMagicNumber);

      return(INIT_SUCCEEDED);
}

void  CGridMaster::Setup(){
      ReadInputIterationModeAndProfit();
      mSymbolMagicTypeOrdersTotal = CountOrder(mSymbol, mMagicNumber, mOrderType, MODE_TRADES);
      
      ResetOrderData(mSubGrid.BottomOrder);
      ResetOrderData(mSubGrid.MidOrder);
      ResetOrderData(mSubGrid.TopOrder);
      
      GetOrdersOpened();
      GetSubGridOrders();
      GetGridStats();
      
      //---CritClose SetTimeRange
      CritSetTimeRange();
      
      if (mIsOneChartSetup == false) {
         mMasterInfo = new CGridDashboard(OrderTypeName(mOrderType)+"MasterGridDB",SetCornerForGridDashboard(mOrderType),400,15,15,4);
         mSubInfo = new CGridDashboard(OrderTypeName(mOrderType)+"SubGridDB",SetCornerForGridDashboard(mOrderType),10,15,15,3);
         }
      mFirstTime = false;
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
   IsPanicClose();
   IsDuringCritical();
   //PrintFormat(__FUNCTION__+": PanicOrderCount %d, CurrentSize %d, %s",mPanicCloseOrderCountTrigger, mSize, (string)IsPanicClose());
   //GetSubGridModeAndOrdersPos();
   //GetIterationModeAndProfit();
   
}

double CGridMaster::GetProfit()     //Change to MQL5 syntax
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

void  CGridMaster::GetOrdersOpened(){              //Change to MQL5 syntax
   #ifdef _DEBUG
      PrintFormat(__FUNCTION__+"Start getting MasterGrid order");           
   #endif
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
	//check if it is a new grid, then reset mIteration and PanicIteration to 1
	if (IsNewGrid()){
	   mIteration = 1;
	   mPanicClose.Iteration=1;
	   GetPanicProfitToClose();
	   mPanicClose.Profit=0.0;
	   mIsNewGrid = false;                 //revert back to false
	};
	//GetGridStats();
	//ShowGridOrdersOnChart();
   #ifdef _DEBUG
      PrintFormat(__FUNCTION__+"Complete getting MasterGrid orders");           
   #endif
}

void  CGridMaster::GetOrdersHistory(){          //Change to MQL5 syntax
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
void CGridMaster::RefillGridWithSavedData(SOrderInfo &arr[],SOrderInfo_BinFormat &binarr[])         //Change to MQL5 syntax
{
   if(ArraySize(arr) < ArraySize(binarr)) ArrayResize(arr,ArraySize(binarr));
   
   //--- load data
   for(int i=0;i<ArraySize(arr);i++)
     {
      SetOrderToGrid(arr[i],binarr[i].Ticket,MODE_TRADES);
     }
   GetGridSize();    //Update gridsize
}

int  CGridMaster::SetOrderToGrid(SOrderInfo &gridpos, int ordetic, int pool=MODE_TRADES)             //fill all order details from the input orderticket //Change to MQL5 syntax
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
         if(mOrders[i].Ticket == ordertic) {iPosRemove = i; break;}  else continue;
       }
   RemoveIndexFromArray(mOrders, iPosRemove);
}


//---



int CGridMaster::GetSubGridOrders(){
      GetGridSize();
      GetSubGridModeAndOrdersPos();                //determine: ModeScheme, current Mode (2Node or 3Node), and TopToMidStep
      //#ifdef _DEBUG
      //PrintFormat(__FUNCTION__+": current mode is %s", RescueModeToString(mRescueMode));           
      //#endif
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
                           #ifdef _DEBUG 
                              PrintFormat(__FUNCTION__+"TopOrderTic %d, BottomOrderTic %d, MidOrderTic %d",mOrders[mSubGrid.TopOrderPos].Ticket,mOrders[mSubGrid.BottomOrderPos].Ticket,mOrders[mSubGrid.MidOrderPos].Ticket);
                           #endif
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
	            //ShowGridOrdersOnChart(mSubGrid);   
               return (true);
               }
               }  

     return(false);        
}
//---
int CGridMaster::CloseSubGrid(SSubGrid &subgrid){                          //Change to MQL5 syntax
   int count = OrdersTotal();
   int closecount = 0;
   bool isclosed = false;
   long toporderticket, midorderticket, bottomorderticket;
   double toporderticketprofit, midorderticketprofit, bottomorderticketprofit;
    
   //handle iteration-base rescue switch---

   double profittoclose = (mRescueScheme==_iteration_based_)? mIterationProfitToClose : mProfitToClose;
     
   if(subgrid.Profit >= profittoclose)
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
                  if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0))
                     {toporderticket = subgrid.TopOrder.Ticket; toporderticketprofit = subgrid.TopOrder.Profit+subgrid.TopOrder.Commission+subgrid.TopOrder.Swap; ResetOrderData(subgrid.TopOrder); subgrid.TopOrderPos=0; closecount++;}
                }
              //---  
              if(OrderTicket() == subgrid.BottomOrder.Ticket 
                 &&  OrderMagicNumber() == mMagicNumber
                  )
                {
                  if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0))
                  {bottomorderticket = subgrid.BottomOrder.Ticket; bottomorderticketprofit = subgrid.BottomOrder.Profit+subgrid.BottomOrder.Commission+subgrid.BottomOrder.Swap; ResetOrderData(subgrid.BottomOrder); subgrid.BottomOrderPos=0;closecount++;}
                }
              //---
              
              if(OrderTicket() == subgrid.MidOrder.Ticket 
                 &&  OrderMagicNumber() == mMagicNumber
                 && mRescueMode == _3NODE
                  )
                {
                  if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0))
                  {midorderticket = subgrid.MidOrder.Ticket;midorderticketprofit = subgrid.MidOrder.Profit+subgrid.MidOrder.Commission+subgrid.MidOrder.Swap; ResetOrderData(subgrid.MidOrder); subgrid.MidOrderPos=0;closecount++;}
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
            PrintFormat(__FUNCTION__+" %s:%d:%s Subgrid %d($%.2f), %s($%s), %d($%.2f) tics closed at %s"
                        , mSymbol, mMagicNumber, OrderTypeName(mOrderType), toporderticket,toporderticketprofit
                        , BlankFormat(midorderticket),BlankFormat((int)midorderticketprofit), bottomorderticket,bottomorderticketprofit, TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
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
		//if(mIsPanic)
		mMasterInfo.mDashboard.SetRowText(ArraySize(mOrders)+_headerrowstoskip+2,StringFormat("IsPanic %s, PanicPF(Target): %.2f (%.2f)| Iter|Cnt:%d|%d ",(string)mIsPanic,mPanicClose.Profit,mPanicClose.TrailingProfitToClose,mPanicClose.Iteration,mPanicCloseRescueCount));
		mMasterInfo.mDashboard.SetRowText(ArraySize(mOrders)+_headerrowstoskip+3,StringFormat("IsCrit %s, Count: %d ",(string)mIsDuringCritical,mCritCloseRescueCount));

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
      mSubInfo.mDashboard.SetRowText(11,StringFormat(" %d Panic has been closed" , mPanicCloseRescueCount));                                                                                                                           	   

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
         //#ifdef _DEBUG PrintFormat(__FUNCTION__+": Current iteration Mode is %s, profitToClose is %.2f",RescueModeToString(mRescueMode),mIterationProfitToClose); #endif
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
   mSubGrid.TopOrderPos = 0;                                   // 0 is the Largest size order
   mSubGrid.MidOrderPos = mSubGrid.TopOrderPos+mSubGrid.TopToMidStep;
   mSubGrid.BottomOrderPos = mSize-1;                         // mSize - 1 is the smallest order  

}  
//---Iteration-base rescue

int   CGridMaster::ReadInputIterationModeAndProfit(){
   #ifdef _DEBUG PrintFormat(__FUNCTION__+": Starting......");           #endif
   int sep_pos;
   if(StringSplitToArray(mIterationInputStrings, mIterationInputStringList,",")>0){
      ArrayResize(mIterations,ArraySize(mIterationInputStrings));
      for(int i=ArraySize(mIterationInputStrings)-1;i>=0;i--)
        {

         mIterations[i].Input = StringTrimRightMQL(StringTrimLeftMQL(mIterationInputStrings[i]));             //pass in the text input, make sure no trailing blank
         
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
   #ifdef _DEBUG PrintFormat(__FUNCTION__+": Complete......");           #endif
   return(0);
}

void CGridMaster::GetIterationModeAndProfit()
{
        mRescueMode = IntToRescueMode(mIterations[mIteration-1].Mode);
        mIterationProfitToClose = mIterations[mIteration-1].ProfitToClose;
}

/*
int   CGridMaster::GetSymbolMagicTypeOrdersTotal()       //Change to MQL5 syntax
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
*/

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

int CGridMaster::ClosePanicCloseOrders()                 //Change to MQL5 syntax
{  
   int closecount = 0;
   int minsize = (mPanicClose.LotSize==true) ? 2 : 3;
   long toporderticket, secondorderticket;
   double toporderticketprofit, secondorderticketprofit;
   if(mIsPanic == true)
     {
       if(mSize <= minsize || mPanicClose.Iteration > mPanicCloseNStop) return(0);
       else{
          if(mPanicClose.Profit>= mPanicClose.TrailingProfitToClose)
            {
               if(OrderSelect(mPanicClose.TopOrder.Ticket, SELECT_BY_TICKET, MODE_TRADES))
                  {if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0))
                     {toporderticket = mPanicClose.TopOrder.Ticket; toporderticketprofit = mPanicClose.TopOrder.Profit+mPanicClose.TopOrder.Commission+mPanicClose.TopOrder.Swap; 
                     ResetOrderData(mPanicClose.TopOrder); closecount++;}
                  }
               if(OrderSelect(mPanicClose.SecondOrder.Ticket, SELECT_BY_TICKET, MODE_TRADES))
                  {if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0))
                  {secondorderticket = mPanicClose.SecondOrder.Ticket; secondorderticketprofit= mPanicClose.SecondOrder.Profit+mPanicClose.SecondOrder.Commission+mPanicClose.SecondOrder.Swap;
                  ResetOrderData(mPanicClose.SecondOrder); closecount++;}
                  }
            }
           }  
     }
   if(closecount >=1) {
   mPanicClose.Iteration++;
   mPanicCloseRescueCount++;
   RefreshGridAfterClose();
   GetPanicProfitToClose();            //update the mPanicClose.TrailingProfitToClose for next panic close iteration
   
   PrintFormat(__FUNCTION__+"  %s:%d:%s PanicClosed tic %d($%.2f) & %d($%.2f) at %s"
               , mSymbol, mMagicNumber, OrderTypeName(mOrderType),toporderticket, toporderticketprofit, secondorderticket, secondorderticketprofit, TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
   return(1);
   }
   return(0);   

}

int   CGridMaster::GetPanicCloseOrders(int inputpos=0)          
{  

   int secondorderpos;                        
   if(mPanicClose.LotSize==true && mSize ==3 && mPanicClose.Iteration>1) {
      secondorderpos = mSize-1;                 //in case LotSize trigger and panic for a while, and mSize is 3, then panicclose Top and Bottom order
      } else {
      secondorderpos = mSize-1-inputpos;      //inputpos is from largest order, so need to reverse it by mSize-1 
      } 
   GetPanicProfitToClose();
   if (inputpos>=mSize-1) return(0); 
   if(mIsPanic==true)
     {
      mPanicClose.TopOrder    = mOrders[0];                             //this is the smallest size order
      
      mPanicClose.SecondOrder = mOrders[secondorderpos];
      mPanicClose.Profit      = mOrders[0].Profit+ mOrders[0].Swap+ mOrders[0].Commission
                                +mOrders[secondorderpos].Profit+ mOrders[secondorderpos].Swap+ mOrders[secondorderpos].Commission;
      #ifdef _DEBUG
         PrintFormat(__FUNCTION__+"TopPanicOrder Ticket %d, SecondPanicOrder Ticket %d",mOrders[0].Ticket, mOrders[secondorderpos].Ticket);
      #endif
     return(1);
     }
   return(0);
}

void   CGridMaster::GetPanicProfitToClose()
{
   if (mPanicClose.Iteration==1) mPanicClose.TrailingProfitToClose = mPanicCloseProfitToClose;
   else{
      if (mPanicCloseIsDriftProfit == true 
         && MathAbs(mPanicClose.TrailingProfitToClose - mPanicCloseProfitToClose) <= mPanicCloseProfitDriftLimit)
          mPanicClose.TrailingProfitToClose= mPanicCloseProfitToClose + ((mPanicClose.Iteration-1)*mPanicCloseProfitDriftStep);
   }
  
}


bool CGridMaster::IsPanicClose()
{
   bool ispanic = false;
   int triggercount = 0;
   if (mPanicCloseOrderCountTrigger!=0 ){
      if(mSize >= mPanicCloseOrderCountTrigger) {triggercount++; mPanicClose.OrderCount=true ;} 
      else { mPanicClose.OrderCount=false ;}
      }
   if (mPanicCloseDrawDownTrigger!=0){
      if (mProfit <= mPanicCloseDrawDownTrigger) {triggercount++; mPanicClose.Drawdown=true;} else {mPanicClose.Drawdown=false;}
      }
   if (mPanicCloseMaxLotSizeTrigger!=0) {
      if (mMaxLotSize >= mPanicCloseMaxLotSizeTrigger) {triggercount++; mPanicClose.LotSize=true;} else {mPanicClose.LotSize=false;}
      }
         
   if(triggercount>=1) ispanic = true;
   mIsPanic = ispanic;
   return (ispanic);

}
//+------------------------------------------------------------------+
//|      TIME CRITICAL CLOSE                                         |
//+------------------------------------------------------------------+

void  CGridMaster::CritSetTimeRange(){
 string  timeranges[]; 
 string  period[2];        //hold start & end 's hour and minutes in string;
 STime   _start;            // hold start hour & minute int
 STime   _end;              // hold end hour & minute int

 int timerangesCount = StringSplitToArray(timeranges,mCritCloseInputTimeRangeString,",");
 
 ArrayResize(mCritClose.TimeRange, timerangesCount);
 if(timerangesCount>0){
      for(int i=0;i<timerangesCount;i++)
        {
         #ifdef _DEBUG PrintFormat(__FUNCTION__+"Timerange: %s",timeranges[i]); #endif
         StringSplitToArray(period,timeranges[i],"-");       //Split StartTime and EndTime by "-"
         SplitHourAndMinute(_start, period[0]);              //get hour and minute of Start time
         SplitHourAndMinute(_end, period[1]);                //get hour and minute of End time
         
         mCritClose.TimeRange[i] = new CSignalTimeRange(_start.Hour
                                                       ,_start.Minute
                                                       ,_end.Hour
                                                       ,_end.Minute
                                                      );
       
        #ifdef _DEBUG PrintFormat(__FUNCTION__+"time[%d], StartHour:[%d],StartMinute:[%d],EndHour:[%d],EndMinute:[%d]"
                                  ,i
                                  ,mCritClose.TimeRange[i].mStartHour
                                  ,mCritClose.TimeRange[i].mStartMinute
                                 ,mCritClose.TimeRange[i].mEndHour
                                 ,mCritClose.TimeRange[i].mEndMinute
                                 ); 
        #endif  
        }
   }
}

void  CGridMaster::SplitHourAndMinute(STime &time, string timestring){
      timestring = StringTrimRightMQL(StringTrimLeftMQL(timestring)); //clean up all trailing blank
      int sep_pos = StringFind(timestring,":");
      if(sep_pos>=0){
              time.Hour = StringToInteger(StringSubstr(timestring,0,sep_pos));
              time.Minute = StringToInteger(StringSubstr(timestring,sep_pos+1));
      }  
}

int CGridMaster::CloseCritCloseOrders()                 //Change to MQL5 syntax
{  
   int closecount = 0;
   int  forceclosecount = 0;
   long toporderticket, bottomorderticket;
   double toporderticketprofit, bottomorderticketprofit;

   if(mIsPanic == true && IsDuringCritical())       //If Panic during the Critical Timerange
     {                                                  
     if (GetCritBottomOrderDuration() >= mCritCloseMaxOpenMinute)  //if the bottom order has opened more than N minutes
      {
        #ifdef _DEBUG
              PrintFormat(__FUNCTION__+"PanicGridSize: %s, PanicMaxLot: %s, PanicDD: %s | SelectedReason: %s --> %s"
                          , (string) mPanicClose.OrderCount, (string) mPanicClose.LotSize, (string)mPanicClose.Drawdown, 
                          EnumToString(mCritClosePanicReason),  (string) CritCheckIfPanicOf() );
              #endif
        if(mCritClose.TopOrderProfit>= mCritProfitToCloseTopOrder   //if toporderProfit >= profit to close
            && CritCheckIfPanicOf()==true                           //if only the selected panic reason is met 
            )    
            {
               if(OrderSelect(mCritClose.TopOrder.Ticket, SELECT_BY_TICKET, MODE_TRADES))
                  {if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0))
                     {toporderticket = mCritClose.TopOrder.Ticket; toporderticketprofit = mCritClose.TopOrder.Profit+mCritClose.TopOrder.Commission+mCritClose.TopOrder.Swap;
                     ResetOrderData(mCritClose.TopOrder); closecount++;}
                  }
               if(OrderSelect(mCritClose.BottomOrder.Ticket, SELECT_BY_TICKET, MODE_TRADES))
                  {if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0))
                     {bottomorderticket = mCritClose.BottomOrder.Ticket; bottomorderticketprofit = mCritClose.BottomOrder.Profit+mCritClose.BottomOrder.Commission+mCritClose.BottomOrder.Swap;
                     ResetOrderData(mCritClose.BottomOrder); closecount++;}
                  }
            }   
       }    
        //--- ForceClose option
        //
      if(IsCritAtEndTime() && mCritForceCloseAtEndTime == true             // if ignore BottomOrder duration
         && mCritClose.IsEndTimeHasClosed == false) {//if onRangeEnd and ForceClose = true and has not been force close before
         if(mCritForceCloseAtEndTimeIgnoreDuration==true
            || (mCritForceCloseAtEndTimeIgnoreDuration==false && GetCritBottomOrderDuration() >= mCritCloseMaxOpenMinute ) )
           {
            if(OrderSelect(mCritClose.TopOrder.Ticket, SELECT_BY_TICKET, MODE_TRADES))
                  {if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0))
                     {toporderticket = mCritClose.TopOrder.Ticket; toporderticketprofit = mCritClose.TopOrder.Profit+mCritClose.TopOrder.Commission+mCritClose.TopOrder.Swap;
                        ResetOrderData(mCritClose.TopOrder); forceclosecount++;}
                  }
            if(OrderSelect(mCritClose.BottomOrder.Ticket, SELECT_BY_TICKET, MODE_TRADES))
                  {if(OrderClose(OrderTicket(),OrderLots(), OrderClosePrice(),0))
                     {bottomorderticket = mCritClose.BottomOrder.Ticket; bottomorderticketprofit = mCritClose.BottomOrder.Profit+mCritClose.BottomOrder.Commission+mCritClose.BottomOrder.Swap;
                     ResetOrderData(mCritClose.BottomOrder); forceclosecount++;}
                  }
           }
        }   
     }
   if(closecount >=1) {
   mCritCloseRescueCount++;
   RefreshGridAfterClose();
   PrintFormat(__FUNCTION__+"  %s:%d:%s CritClosed tic %d($%.2f) & %d($%.2f) at %s"
               , mSymbol, mMagicNumber, OrderTypeName(mOrderType),toporderticket, toporderticketprofit, bottomorderticket, bottomorderticketprofit, TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
   return(1);
   }
    if(forceclosecount >=1) {
   mCritCloseRescueCount++;
   mCritClose.IsEndTimeHasClosed = true;
   RefreshGridAfterClose();
   PrintFormat(__FUNCTION__+"  %s:%d:%s CritForceClosed tic %d($%.2f) & %d($%.2f) at %s"
               , mSymbol, mMagicNumber, OrderTypeName(mOrderType),toporderticket, toporderticketprofit, bottomorderticket, bottomorderticketprofit, TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
   return(1);
   }
   return(0);   

}
//---

int   CGridMaster::GetCritCloseOrders()          
{  
   if( mIsPanic==true && IsDuringCritical() )                                             //CritClose is conditional on Panic status
     {
      mCritClose.TopOrder    = mOrders[0];                             //this is the Biggest size order
      mCritClose.BottomOrder = mOrders[mSize-1];                      //this is the smallest size order
      mCritClose.TopOrderProfit      = mOrders[0].Profit+ mOrders[0].Swap+ mOrders[0].Commission;
      #ifdef _DEBUG
         PrintFormat(__FUNCTION__+"TopCritOrder Ticket %d (Profit: %.2f), BottomCritOrder Ticket %d",mOrders[0].Ticket, mCritClose.TopOrderProfit, mOrders[mSize-1].Ticket);
      #endif
     return(1);
     }
     else if (!IsDuringCritical()){       //reset CritClose orders and ForceClose paramters 
      CritCloseReset();
      return(0);
     }
   return(0);
}
//---

int CGridMaster::GetCritBottomOrderDuration()                 
{
  int duration = 0;
  int bottomOrderDuration = NormalizeDouble(((int) TimeCurrent() - (int) mCritClose.BottomOrder.OpenTimeDt) / 60,0); //convert to minute
  #ifdef _DEBUG
         PrintFormat(__FUNCTION__+"BottomOrder OpenTime: %s, now is %s, duration is %d mins", TimeToStr(mCritClose.BottomOrder.OpenTimeDt), TimeToStr(TimeCurrent()), bottomOrderDuration);
  #endif
  if(bottomOrderDuration > duration) duration = bottomOrderDuration;
  return (duration);
}
//---

bool CGridMaster::CritCheckIfPanicOf()
{
  bool isValid = false;
  if (mCritClosePanicReason == _1_or_more_panic_reason_ && mIsPanic) {isValid = true; return(isValid);}
  if (mCritClosePanicReason == _for_drawdown_only_ && mPanicClose.Drawdown==true) {isValid = true; return(isValid);}
  if (mCritClosePanicReason == _for_maxlot_only_ && mPanicClose.LotSize==true) {isValid = true; return(isValid);}
  if (mCritClosePanicReason == _for_drawdown_and_maxlot_ 
    && (mPanicClose.Drawdown==true && mPanicClose.LotSize==true) ) {isValid = true; return(isValid);}
  if (mCritClosePanicReason == _for_drawdown_or_maxlot_ 
    && (mPanicClose.Drawdown==true || mPanicClose.LotSize==true) ) {isValid = true; return(isValid);}
  
  return(isValid);
} 

//---

bool  CGridMaster::IsDuringCritical()
{
  bool  isInside = false;
  int size = ArraySize(mCritClose.TimeRange);
  int insideRangeCount = 0;
  for(int i = 0; i <=size - 1; i++){
    if(!mCritClose.TimeRange[i].InsideRange()) continue;
    else insideRangeCount++;
  }
  if(insideRangeCount>=1) isInside = true;
  mIsDuringCritical = isInside;
  return(isInside);
}

//---
void  CGridMaster::CritCloseReset()
{
    mIsDuringCritical = IsDuringCritical();
    ResetOrderData(mCritClose.TopOrder);
    ResetOrderData(mCritClose.BottomOrder);
    mCritClose.IsEndTimeHasClosed = false;

}

//---

bool  CGridMaster::IsCritAtEndTime()
{
  bool  isOnRangeEnd = false;
  int size = ArraySize(mCritClose.TimeRange);
  int onRangeEndCount = 0;
  for(int i = 0; i <=size - 1; i++){
    if(!mCritClose.TimeRange[i].OnRangeEnd()) continue;
    else onRangeEndCount++;
  }
  if(onRangeEndCount>=1) isOnRangeEnd = true;
  return(isOnRangeEnd);
}
//---


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

void FillGridOrder(                                            //Change to MQL5 syntax
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
   thisOrder.Lots = NormalizeDouble(lot,2);
   thisOrder.OpenPrice = NormalizeDouble(openprice,SymbolInfoInteger(symbol,SYMBOL_DIGITS));
   thisOrder.StopLoss= NormalizeDouble(stoploss,SymbolInfoInteger(symbol,SYMBOL_DIGITS));
   thisOrder.TakeProfit = NormalizeDouble(takeprofit,SymbolInfoInteger(symbol,SYMBOL_DIGITS));
   thisOrder.Comment= comment;
   thisOrder.MagicNumber= magicnumber;
}

//---

void AddOrderToGrid(SOrderInfo &arr[],                           //Change to MQL5 syntax
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
     


        