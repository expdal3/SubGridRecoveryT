/*

	GridTrader Collection
	Expert
	
	Copyright 2022, Orchard Forex
	https://www.orchardforex.com

*/

#include "ExpertCustom.mqh"



struct SPortfolio : SStrategyInput
  {
   CExpertGrid *Expert;
   double	   SymbolPoint;
  }; 


class CExpertCollection : public CExpert {

protected:
   SPortfolio  mPool[];
   string      mSymbolStringList;
   string      mSuffix;   
   string      mMagicStringList;
   CStrategyInput *mPoolInput;
   
	double	mMultiplierFactor;                                    //FactorMultipler
	double   mProfitToClose;
   double   mLossToClose;
	double   mLevelPoints;                                         //gap in points between level (this need to be processed further into Price for different pair)
	int      mLevelToStartAveraging;
	double   mOrderSize;
	string   mTradeComment;
   
   ENUM_GRID_TRAILORDERSIZE_OPT mTrailOrderSizeOption;
	ENUM_TRADE_MODES mTradeMode;
   CSignalTimeRangeCollection*   mTradingTime;          //hold TimeRange info
   CSignalTimeRangeCollection*   mTradingTimeFriday;          //hold TimeRange info
   string              mTimeRangeString;    //hold TimeRange info in String
   string              mTimeRangeStringFriday;
   
   int      mFirstTime;
   bool      mDebug;
public:

	CExpertCollection(string symbolStringList,string suffix,string magicStringList
	                  ,string timeRangeString,string timeRangeStringFriday, ENUM_GRID_TRAILORDERSIZE_OPT trailOrderSizeOption , double multiplyFactor, double profitToClose, double lossToClose, int levelPoints,int levelToStartAveraging, double orderSize, string tradeComment, ENUM_TRADE_MODES tradeMode
				         ,bool debug);
	~CExpertCollection();
   
   void        OnTick();
   void        Setup();
   void        SetTradeMode(ENUM_TRADE_MODES tradeMode){mTradeMode = tradeMode; return;};
   void        SplitSymbolStringList();
   void        SplitMagicStringList();
   void        CombineSymbolAndMagicPair();
   void        SetSymbolAndMagicToStruct();
   bool        IsDuringTradingAllowedTime();

};


CExpertCollection::CExpertCollection(string symbolStringList,string suffix,string magicStringList
      	                        ,string timeRangeString, string timeRangeStringFriday, ENUM_GRID_TRAILORDERSIZE_OPT trailOrderSizeOption, double multiplyFactor,	double profitToClose, double lossToClose,int levelPoints,int levelToStartAveraging,double orderSize, string tradeComment, ENUM_TRADE_MODES tradeMode
      				               ,bool debug)
						               :	CExpert("",levelPoints, levelToStartAveraging, trailOrderSizeOption, orderSize, tradeComment, 0) {

	mSymbolStringList =  symbolStringList;
	mSuffix           = suffix;
	mMagicStringList =  magicStringList;
	mLevelPoints		=	levelPoints;
	mMultiplierFactor = multiplyFactor;
   mProfitToClose = profitToClose;
   mLossToClose =    lossToClose;
   mLevelToStartAveraging = levelToStartAveraging;
   mOrderSize     = orderSize; 
   mTradeComment       = tradeComment;
   mTrailOrderSizeOption = trailOrderSizeOption;
   mTradeMode     = tradeMode;
   mTimeRangeString = timeRangeString;
   mTimeRangeStringFriday = timeRangeStringFriday;
   mFirstTime     = true;
   mDebug         = debug;       
	
	mInitResult		=	INIT_SUCCEEDED;
	
}
void		CExpertCollection::OnTick() {
   
   if (mFirstTime == true) 	{Setup(); mFirstTime=false;}
   //#ifdef _DEBUG 
 
   //#endif
   MqlDateTime mqlNow;   
   TimeCurrent(mqlNow);  
   bool isInRange = false;
   if  (mqlNow.day_of_week  >= 1 && mqlNow.day_of_week  <=4 ) isInRange = mTradingTime.IsInRange();
   else isInRange = mTradingTimeFriday.IsInRange();   
   PrintFormat(__FUNCTION__+"IsInRange: %s", (string) isInRange);
   PrintFormat("Current Day is: %s ", DayOfWeekStr( mqlNow.day_of_week));
   for(int i=0;i<=ArraySize(mPool)-1;i++){
      if(!isInRange){                  // if outside of trading time range
      
      //#ifdef _DEBUG PrintFormat(__FUNCTION__+"BuySize: %d, SellSize: %d --> %s",mPool[i].Expert.GetGridSize(POSITION_TYPE_BUY),mPool[i].Expert.GetGridSize(POSITION_TYPE_SELL),
      //  (string)  ( mPool[i].Expert.GetGridSize(POSITION_TYPE_BUY) >0 
      //      || mPool[i].Expert.GetGridSize(POSITION_TYPE_SELL) >0
      //      ));
      //      #endif
         
         if( mPool[i].Expert.GetGridSize(POSITION_TYPE_BUY) >0 
            || mPool[i].Expert.GetGridSize(POSITION_TYPE_SELL) >0
            )  mPool[i].Expert.Loop(isInRange);                //continue to trade if some order of the grid still opened
         else continue;
      } else {                                        // if during trading time range
        mPool[i].Expert.Loop(isInRange);     //loop through each of the SymbolPair
      }
      
   }
}



void		CExpertCollection::Setup() {

   mPoolInput = new CStrategyInput(mSymbolStringList, mSuffix, mMagicStringList);
   mPoolInput.GetSymbolMagicStruct(mPool);
   
   mTradingTime = new CSignalTimeRangeCollection(mTimeRangeString);
   mTradingTime.SetTimeRange();

   mTradingTimeFriday = new CSignalTimeRangeCollection(mTimeRangeStringFriday);
   mTradingTimeFriday.SetTimeRange();
   
    if(mDebug == true) mPoolInput.PrintInput();
   for(int i=0;i<=ArraySize(mPool)-1;i++) {      
   //initial GridExpert object

   mPool[i].Expert = new CExpertGrid(mPool[i].Symbol, mMultiplierFactor, mProfitToClose, mLossToClose, mLevelPoints, mLevelToStartAveraging, mTrailOrderSizeOption, mOrderSize, mTradeComment, mPool[i].Magic);
   mPool[i].Expert.SetTradeMode(mTradeMode);
   } 
}



CExpertCollection::~CExpertCollection() {

	for(int i=ArraySize(mPool)-1;i>=0;i--) delete	mPool[i].Expert;   

}
