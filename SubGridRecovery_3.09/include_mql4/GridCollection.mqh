//--- includes
#include "GridOrderManagement.mqh"
#include <Blues/StrategyInputClass.mqh>

struct SGridPool : SStrategyInput
  {
   CGridMaster    *Grid;
   int            OrderType;
   bool           IsValid;
  }; 

struct SRescueParameter
  {
   int OrderType;
   int LevelStartRescue;
   ENUM_BLUES_SUBGRID_MODE_SCHEME RescueScheme;
   double ProfitToClose;
   string IterationInput;
   string RescueComment;
   bool   IsRescueAllowed;
   //panic params
   int    PanicOrderCount;
   double PanicMaxDD;
   double PanicMaxLotSize;
   double PanicProfitToClose;
   int    PanicSecondPos;
   int    PanicNStop;
   bool   PanicIsDrift;
   double PanicDriftStep;
   double PanicDriftLimit;
   bool   IsPanicCloseAllowed;
   //CritClose params
   string CritCloseInputTimeRangeString;
   int    CritCloseMaxOpenMinute;
   double CritProfitToCloseTopOrder;
   bool   CritForceCloseAtEndTime;
   bool   CritForceCloseAtEndTimeIgnoreDuration;
   bool   IsCritCloseAllowed;
   };  


class CGridCollection
  {
public:
   SGridPool            mPool[];          // arrays to hold multiple grid with different symbols and magicnumber
   CTradeInfo           TradeInfo;        // TradeInfo used to search the OrderOpen / OrderHistory

//---Dashboard object
   CGridDashboard       *mInfo;
   int                  mCount;                       // Count number of grid managing  
   bool                 mIsOneChartSetup; 
protected:
   string               mSymbolStringList;            // StringList of Symbol name from user input
   string               mSuffix;                // SymbolSuffix - provided by user
   string               mMagicStringList;       // StringList of Magicnumber from user input
   CStrategyInput       *mPoolInput;
   SRescueParameter     mParams;
   int                  mCheckNewGridCount;       //count of checking new grid for n time - stop after this reached       
   bool                 mIsRescueInProgress;
   
protected:
   int                  mFirstTime;
   bool                 mDebug;
  
  
public:
                     CGridCollection(string symbolStrList, string symbolSuffix,string magicStrList
                                    ,int orderType,int levelStartRescue,ENUM_BLUES_SUBGRID_MODE_SCHEME rescueScheme ,double profitToClose,string iterationInput,string rescueComment, bool isRescueAllowed
                                    ,int panicOrderCount, double panicMaxDD, double panicMaxLotSize, double panicProfitToClose,int panicSecondPos, int panicNStop, bool panicIsDrift, double panicDriftStep, double panicDriftLimit, bool isPanicCloseAllowed
                                    ,string critCloseInputTimeRangeString, int critCloseMaxOpenMinute, double critProfitToCloseTopOrder, bool critForceCloseAtEndTime, bool critForceCloseIgnoreDuration, bool isCritCloseAllowed
                                    ,bool isOneChartSetup
                                    )
                                    :mSymbolStringList(symbolStrList)
                                    ,mSuffix(symbolSuffix)
                                    ,mMagicStringList(magicStrList)
                                    ,mIsOneChartSetup (isOneChartSetup)  
                                    {Init(orderType, levelStartRescue,rescueScheme,profitToClose,iterationInput,rescueComment, isRescueAllowed
                                       ,panicOrderCount,panicMaxDD,panicMaxLotSize, panicProfitToClose, panicSecondPos, panicNStop, panicIsDrift, panicDriftStep,panicDriftLimit, isPanicCloseAllowed
                                       ,critCloseInputTimeRangeString, critCloseMaxOpenMinute, critProfitToCloseTopOrder, critForceCloseAtEndTime, critForceCloseIgnoreDuration, isCritCloseAllowed
                                       );};
                    ~CGridCollection(void);
protected:
                    int    Init(int orderType,int levelStartRescue,ENUM_BLUES_SUBGRID_MODE_SCHEME rescueScheme ,double profitToClose,string iterationInput,string rescueComment, bool isRescueAllowed
                              ,int panicOrderCount, double panicMaxDD, double panicMaxLotSize, double panicProfitToClose,int panicSecondPos, int panicNStop, bool panicIsDrift, double panicDriftStep, double panicDriftLimit, bool isPanicCloseAllowed
                              ,string critCloseInputTimeRangeString, int critCloseMaxOpenMinute, double critProfitToCloseTopOrder, bool critForceCloseAtEndTime, bool critForceCloseIgnoreDuration, bool isCritCloseAllowed
                              );
                    //---initial setup
                    void   Setup();
                    void   SetRescueParameters(
                                  int orderType,int levelStartRescue,ENUM_BLUES_SUBGRID_MODE_SCHEME rescueScheme ,double profitToClose,string iterationInput,string rescueComment, bool isRescueAllowed
                                 ,int panicOrderCount, double panicMaxDD, double panicMaxLotSize, double panicProfitToClose,int panicSecondPos, int panicNStop, bool panicIsDrift, double panicDriftStep, double panicDriftLimit, bool isPanicCloseAllowed
                                 ,string critCloseInputTimeRangeString, int critCloseMaxOpenMinute, double critProfitToCloseTopOrder, bool critForceCloseAtEndTime, bool critForceCloseIgnoreDuration, bool isCritCloseAllowed
                                  );
                    void   SetGrid(string symbol, int magic, int i);        //If new grid is found from the symbol and magic combo, add new gridmaster object to the collection              
                    bool   IsRescueInProgress();
                    int    GetRescueFrequency(){
                     int freq=2;
                     if(mIsRescueInProgress) freq = 3; else freq = 8; 
                     return(freq);
                     }
                    int    CountValid(){
                        int size = ArraySize(mPool);
                        int count = 0;
                        for(int i=0;i<=size-1;i++)
                          {
                           if(mPool[i].IsValid == false) continue;
                           else count++;
                          }
                        return(count);
                    }
                    
                    ;
                    //---Loop
public:
                    void   OnTick(bool debug=false);
                    void   RescueGrid(int index, bool debug=false);
                    void   GetMasterGrid(int index, bool debug=false);
                    void   ShowCollectionOrdersOnChart();

};


int  CGridCollection::Init(int orderType,int levelStartRescue,ENUM_BLUES_SUBGRID_MODE_SCHEME rescueScheme ,double profitToClose,string iterationInput,string rescueComment, bool isRescueAllowed
                           ,int panicOrderCount, double panicMaxDD, double panicMaxLotSize, double panicProfitToClose,int panicSecondPos, int panicNStop, bool panicIsDrift, double panicDriftStep, double panicDriftLimit, bool isPanicCloseAllowed
                           ,string critCloseInputTimeRangeString, int critCloseMaxOpenMinute, double critProfitToCloseTopOrder, bool critForceCloseAtEndTime, bool critForceCloseIgnoreDuration, bool isCritCloseAllowed
                           ){
      SetRescueParameters(
            orderType, levelStartRescue,rescueScheme,profitToClose,iterationInput,rescueComment, isRescueAllowed
            ,panicOrderCount, panicMaxDD, panicMaxLotSize, panicProfitToClose, panicSecondPos, panicNStop, panicIsDrift, panicDriftStep, panicDriftLimit, isPanicCloseAllowed
            ,critCloseInputTimeRangeString, critCloseMaxOpenMinute, critProfitToCloseTopOrder, critForceCloseAtEndTime, critForceCloseIgnoreDuration, isCritCloseAllowed
            );
      mFirstTime = true;      
      mCheckNewGridCount = 0;
      mIsRescueInProgress = false;
      return(INIT_SUCCEEDED);
}

void  CGridCollection::SetRescueParameters(int orderType,int levelStartRescue,ENUM_BLUES_SUBGRID_MODE_SCHEME rescueScheme ,double profitToClose,string iterationInput,string rescueComment, bool isRescueAllowed
                                       ,int panicOrderCount, double panicMaxDD, double panicMaxLotSize, double panicProfitToClose,int panicSecondPos, int panicNStop, bool panicIsDrift, double panicDriftStep, double panicDriftLimit, bool isPanicCloseAllowed
                                       ,string critCloseInputTimeRangeString, int critCloseMaxOpenMinute, double critProfitToCloseTopOrder, bool critForceCloseAtEndTime, bool critForceCloseIgnoreDuration, bool isCritCloseAllowed
                                       )
{
      mParams.IsRescueAllowed = isRescueAllowed;
      
      mParams.OrderType = orderType;
      mParams.LevelStartRescue = levelStartRescue;
      mParams.RescueScheme = rescueScheme;
      mParams.ProfitToClose = profitToClose;
      mParams.IterationInput = iterationInput;
      mParams.RescueComment = rescueComment;
      mParams.PanicOrderCount = panicOrderCount;
      mParams.PanicMaxDD = panicMaxDD;
      mParams.PanicMaxLotSize = panicMaxLotSize;
      mParams.PanicProfitToClose = panicProfitToClose;
      mParams.PanicSecondPos = panicSecondPos;
      mParams.PanicNStop = panicNStop;
      mParams.PanicIsDrift = panicIsDrift;
      mParams.PanicDriftStep = panicDriftStep;      
      mParams.PanicDriftLimit = panicDriftLimit;
      mParams.IsPanicCloseAllowed = isPanicCloseAllowed;
      
      mParams.IsCritCloseAllowed = isCritCloseAllowed;
      mParams.CritCloseInputTimeRangeString = critCloseInputTimeRangeString;
      mParams.CritCloseMaxOpenMinute = critCloseMaxOpenMinute;
      mParams.CritProfitToCloseTopOrder = critProfitToCloseTopOrder;
      mParams.CritForceCloseAtEndTime = critForceCloseAtEndTime;
      mParams.CritForceCloseAtEndTimeIgnoreDuration = critForceCloseIgnoreDuration;

}

void		CGridCollection::Setup() {

   mPoolInput = new CStrategyInput(mSymbolStringList, mSuffix, mMagicStringList);
   mPoolInput.GetSymbolMagicStruct(mPool);
   int count = ArraySize(mPool);
    if(mDebug == true) mPoolInput.PrintInput();
   for(int i=0;i<=count-1;i++) {
    #ifdef _DEBUG
      PrintFormat(__FUNCTION__+"mParams.OrderType is %s: ", OrderTypeName(mParams.OrderType));           
   #endif
       mPool[i].OrderType = mParams.OrderType;      
   //initial CGridMaster object base on any current open position
       if(!TradeInfo.IsOrderExist(mPool[i].Symbol, mPool[i].Magic, mParams.OrderType)) {
         mPool[i].IsValid = false;
         continue;
       } else {
         SetGrid(mPool[i].Symbol, mPool[i].Magic, i);
      } 
    #ifdef _DEBUG
      PrintFormat(__FUNCTION__+"OrderType of GridMaster %s:%d [i=%d] is %s ", mPool[i].Symbol, mPool[i].Magic,i, OrderTypeName(mPool[i].OrderType));           
   #endif
   
   }

   
}

void  CGridCollection::SetGrid(string symbol, int magic, int i){
         mPool[i].Grid = new CGridMaster(symbol,magic,mParams.OrderType
                                  ,mParams.LevelStartRescue,mParams.RescueScheme,mParams.ProfitToClose,mParams.IterationInput,mParams.RescueComment,mIsOneChartSetup);      //initialize Grid
         mPool[i].Grid.SetPanicCloseParameters(
                           mParams.PanicOrderCount,mParams.PanicMaxDD,mParams.PanicMaxLotSize,mParams.PanicProfitToClose,mParams.PanicSecondPos,mParams.PanicNStop
                           ,mParams.PanicIsDrift, mParams.PanicDriftStep,mParams.PanicDriftLimit
                           );                       //load in panicclose parameters

         mPool[i].Grid.SetCritCloseParameters(
                           mParams.CritCloseInputTimeRangeString,mParams.CritCloseMaxOpenMinute,mParams.CritProfitToCloseTopOrder,mParams.CritForceCloseAtEndTime, mParams.CritForceCloseAtEndTimeIgnoreDuration
                           );                       //load in CritClose parameters
         
         if(mPool[i].Grid.mFirstTime == true)
           {
            mPool[i].Grid.Setup();
           }
         mPool[i].IsValid = true;
         
   #ifdef _DEBUG
      PrintFormat(__FUNCTION__+"Finish set up GridMaster %s:%d", symbol, magic);           
   #endif
}




void  CGridCollection::OnTick(bool debug=false){
       
       if (mFirstTime == true) 	{Setup(); mFirstTime=false;}     //run Setup once
       //--- loop through mPool
       //
       //PrintFormat(__FUNCTION__+": Size of GridPool is %d ", ArraySize(mPool));
       //if(IsNewBar() || IsNewSession(GetRescueFrequency())){
        for(int i=0;i<ArraySize(mPool);i++){
         //---check if new grid need instantiate for first 7 days since EA running
         //  
        if(mPool[i].IsValid==false ){
           if(TradeInfo.IsOrderExist(mPool[i].Symbol, mPool[i].Magic, mParams.OrderType)==false) continue;   
           else SetGrid(mPool[i].Symbol, mPool[i].Magic, i);
        } else {
         
           if(mPool[i].Grid.GetSymbolMagicTypeOrdersTotal()==0 ) continue;        //if the grid is currently empty, skip
           else {
   		      if (debug == true )PrintFormat(__FUNCTION__+": Processing Grid %s", mPool[i].Grid.mGridName);
   		            IsRescueInProgress();     //check if any of the grid is being in rescue mode
                     GetMasterGrid(i, debug);
                     RescueGrid(i, debug);
           }
          }
         }
       //}

      if (CountValid()>0) 
         if (IsNewBar() || IsNewSession(5)) ShowCollectionOrdersOnChart();
}

void  CGridCollection::GetMasterGrid(int index, bool debug=false){
      if (debug == true ) PrintFormat(__FUNCTION__+": StartGetMaster %s %s at %s", mPool[index].Grid.mGridName, OrderTypeName(mPool[index].Grid.mOrderType), TimeToString(TimeCurrent(),TIME_SECONDS));

      if(mPool[index].Grid.mSymbolMagicTypeOrdersTotal!=mPool[index].Grid.GetSymbolMagicTypeOrdersTotal()  //if number of opened order changed
         || mPool[index].Grid.IsAGridOrderJustClosed()                                                     //handle partial close event
         )        
         {
            mPool[index].Grid.mSymbolMagicTypeOrdersTotal=mPool[index].Grid.GetSymbolMagicTypeOrdersTotal();
            mPool[index].Grid.GetOrdersOpened();           //pass data to Grid array that match symbol, magicnumber, ordertype
            
         }
      if (debug == true ) PrintFormat(__FUNCTION__+": CompleteGetMaster %s %s at %s", mPool[index].Grid.mGridName, OrderTypeName(mPool[index].Grid.mOrderType), TimeToString(TimeCurrent(),TIME_SECONDS));       

}

void  CGridCollection::RescueGrid(int index, bool debug=false){
        if (debug == true ) PrintFormat(__FUNCTION__+": StartRescue %s %s at %s", mPool[index].Grid.mGridName, OrderTypeName(mPool[index].Grid.mOrderType), TimeToString(TimeCurrent(),TIME_SECONDS));  
         mPool[index].Grid.GetSubGridOrders();
         mPool[index].Grid.GetGridStats();
         
        if (debug == true ) PrintFormat(__FUNCTION__+": Grid %s, mIsRecovering: %s", mPool[index].Grid.mGridName, (string) mPool[index].Grid.mIsRecovering);  
         //---normal rescue
         if(mParams.IsRescueAllowed==true && mPool[index].Grid.mIsRecovering==true){
            if(mPool[index].Grid.CloseSubGrid(mPool[index].Grid.mSubGrid)){
               mPool[index].Grid.mIteration++; 
               mPool[index].Grid.mRescueCount++;
            }
          
            //--- panic close
            if(mParams.IsPanicCloseAllowed==true && mPool[index].Grid.mIsPanic==true){
            mPool[index].Grid.GetPanicCloseOrders(mPool[index].Grid.mPanicCloseSecondOrderPos);
            mPool[index].Grid.ClosePanicCloseOrders(); 
            }  //end of panicClose
            //--- Crit Close
            if(mParams.IsCritCloseAllowed==true && mPool[index].Grid.mIsPanic==true && mPool[index].Grid.mIsDuringCritical==true){
                  mPool[index].Grid.GetCritCloseOrders();
                  mPool[index].Grid.CloseCritCloseOrders();
            }  //end of critClose
          }
        if (debug == true ) PrintFormat(__FUNCTION__+": CompleteRescue %s %s at %s", mPool[index].Grid.mGridName, OrderTypeName(mPool[index].Grid.mOrderType), TimeToString(TimeCurrent(),TIME_SECONDS));       
}




bool CGridCollection::IsRescueInProgress(){
    bool isRescue = false;

    for(int i=0;i<ArraySize(mPool);i++){
    if(mPool[i].IsValid == true){
    
       if((mPool[i].Grid.mIsRecovering == false && mPool[i].Grid.mIsPanic == false)) continue;
       else {isRescue = true; break;}
      } else {
       //PrintFormat(__FUNCTION__,"this grid % is not existed!", mPool[i].Symbol+":"+IntegerToString(mPool[i].Magic));
       continue   ;
      }
    }
     

    

    mIsRescueInProgress =   isRescue; 
    return(isRescue);
}



void CGridCollection::ShowCollectionOrdersOnChart(){

   int _headerrowstoskip = mInfo.mHeaderRowsToSkip;
   bool  gridisactive = false;
   string blank = "--";
   string _last3digitmagic;
   int magiclen=0;
   int substrpos;
   
   //--- update row text
   for(int x=0;x<ArraySize(mPool);x++)
	  {
	  if (mPool[x].IsValid==false) continue;
	  else{
	  
	    	 magiclen = StringLen(IntegerToString(mPool[x].Grid.mMagicNumber));
      //for(int i=0;i<mPool[x].mSize;i++)
	   //  {
	   //   if(OrderSelect(mPool[x].mOrders[i].Ticket,SELECT_BY_TICKET,MODE_TRADES))        //search if any the grids order ticket is found in OrdersTotal
	   //   {
      //      gridisactive = true;
      //      break;
	   //   }
	   //  }
      if(mPool[x].Grid.GetSymbolMagicTypeOrdersTotal() !=0)
      {
         
         if(magiclen <=3) substrpos = 0;            
         else if (magiclen < 6) substrpos = magiclen -  (magiclen % 3);
         else substrpos = magiclen - 3;
         _last3digitmagic = StringSubstr(IntegerToString(mPool[x].Grid.mMagicNumber),substrpos);
                                                                    
	      mInfo.mDashboard.SetRowText(x+_headerrowstoskip+1,                                        // if ticket if found to be active, show the grid in panel
	                                 StringFormat("%s    %s  %.2f   %d   %s   (%d)   %d   %d" 
	                                               ,mPool[x].Grid.mSymbol+"xx"+_last3digitmagic
	                                               ,OrderTypeName(mPool[x].Grid.mOrderType)
	                                               ,mPool[x].Grid.mProfit
	                                               ,mPool[x].Grid.mSize
	                                               ,(string) mPool[x].Grid.mIsRecovering
	                                               ,mPool[x].Grid.mIteration
	                                               ,mPool[x].Grid.mRescueCount
	                                               ,mPool[x].Grid.mPanicCloseRescueCount
	                                                )
	                                                );
	   }
	   else{
	      mInfo.mDashboard.SetRowText(x+_headerrowstoskip+1, 
	                                 StringFormat("%s   %s   %s   %s   (%s)   %s   %s  %s" 
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                               ,blank
	                                                )
	                                                );
	   
	   } 
      } //
	  }
}

CGridCollection::~CGridCollection() {

	for(int i=ArraySize(mPool)-1;i>=0;i--) delete	mPool[i].Grid;   

}
