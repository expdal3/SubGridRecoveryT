/*

	GridTrader v1
	Expert
	
	Copyright 2022, Orchard Forex
	https://www.orchardforex.com
#ifdef FRAMEWORK_VERSION 
   Print("FRAMEWORK_VERSION is ",__FILE__);   
#endif

#ifdef FRAMEWORK_VERSION_3_06_BLS_MULTIPAIR
   Print("FRAMEWORK_VERSION is BLS_MULTIPAIR");   
#endif

*/

#include <Blues/StrategyInputClass.mqh>
#include <Blues/UtilityFunctions.mqh>
#include <Orchard/Frameworks/Framework.mqh>
#include "Expert.mqh"
#include "Leg.mqh"


class CExpertGrid : public CExpert {

protected:
   CLeg*    mBuyLeg;
   CLeg*    mSellLeg;
   string   mSymbol;
	double	mMultiplierFactor;                                    //FactorMultipler
	double   mProfitToClose;
   double   mLossToClose;
	ENUM_TRADE_MODES mTradeMode;
	ENUM_GRID_TRAILORDERSIZE_OPT mTrailOrderSizeOption;
	int      mLevelToStartAveraging;
	int      mFirstTime;


public:

	CExpertGrid(string symbol, double multiplyFactor,	double profitToClose, double lossToClose
	         ,int levelPoints, int levelToStartAveraging, ENUM_GRID_TRAILORDERSIZE_OPT trailOrderSizeOption                   //add the new 'factor' parameter
				,double orderSize, string tradeComment, long magic);
	~CExpertGrid();
   
   void        Loop(bool isInRange);
   void        SetTradeMode(ENUM_TRADE_MODES tradeMode){mTradeMode = tradeMode; return;};
   int         GetGridSize(int direction);
};


CExpertGrid::CExpertGrid(string symbol, double multiplyFactor, double profitToClose, double lossToClose, int levelPoints, int levelToStartAveraging, ENUM_GRID_TRAILORDERSIZE_OPT trailOrderSizeOption, double orderSize, string tradeComment, long magic)
						:	CExpert(symbol, levelPoints, levelToStartAveraging, trailOrderSizeOption, orderSize, tradeComment, magic) {

   mSymbol        = symbol;
	mLevelSize		=	PointsToDouble(symbol, levelPoints);
	mMultiplierFactor = multiplyFactor;
   mProfitToClose = profitToClose;
   mLossToClose = lossToClose;
   mLevelToStartAveraging = levelToStartAveraging;
	mTrailOrderSizeOption = trailOrderSizeOption;
	mFirstTime     = true;

	mBuyLeg			=	new CLeg(symbol, mMultiplierFactor, mLevelSize, POSITION_TYPE_BUY, levelToStartAveraging, trailOrderSizeOption, mOrderSize, mTradeComment, mMagic);
	mSellLeg			=	new CLeg(symbol, mMultiplierFactor, mLevelSize, POSITION_TYPE_SELL, levelToStartAveraging, trailOrderSizeOption, mOrderSize, mTradeComment, mMagic);
	
	mInitResult		=	INIT_SUCCEEDED;
	
}


CExpertGrid::~CExpertGrid() {

	delete	mBuyLeg;
	delete	mSellLeg;
	
}

void		CExpertGrid::Loop(bool isInRange) {
   
   if(mFirstTime == true)
     {
      mBuyLeg.SetProfitToClose(mProfitToClose);
      mSellLeg.SetProfitToClose(mProfitToClose);
      mBuyLeg.SetLossToClose(mLossToClose);
      mSellLeg.SetLossToClose(mLossToClose);
      mFirstTime = false;
     }

   mBuyLeg.SetIsInRange(isInRange);          //receive the updated value of IsInRange from parent class
	mSellLeg.SetIsInRange(isInRange);
	if(mTradeMode == Buy_and_Sell || mTradeMode == BuyOnly)	   mBuyLeg.OnTick();
	if(mTradeMode  == Buy_and_Sell || mTradeMode == SellOnly)	mSellLeg.OnTick();   
	
}

int        CExpertGrid::GetGridSize(int direction ){
   int size = 0 ;
   if (direction == POSITION_TYPE_BUY) size = mBuyLeg.mCount;
   if (direction == POSITION_TYPE_SELL) size = mSellLeg.mCount;
   return(size);
}