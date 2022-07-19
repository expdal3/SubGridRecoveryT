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
	ENUM_TRADE_MODES mTradeMode;

public:

	CExpertGrid(string symbol, double multiplyFactor,	double profitToClose,
	         int levelPoints,                    //add the new 'factor' parameter
				double orderSize, string tradeComment, long magic);
	~CExpertGrid();
   
   void        Loop();
   void        SetTradeMode(ENUM_TRADE_MODES tradeMode){mTradeMode = tradeMode; return;};
};


CExpertGrid::CExpertGrid(string symbol, double multiplyFactor, double profitToClose, int levelPoints, double orderSize, string tradeComment, long magic)
						:	CExpert(symbol, levelPoints, orderSize, tradeComment, magic) {

   mSymbol        = symbol;
	mLevelSize		=	PointsToDouble(symbol, levelPoints);
	mMultiplierFactor = multiplyFactor;
   mProfitToClose = profitToClose;

	mBuyLeg			=	new CLeg(symbol, mMultiplierFactor, mLevelSize, POSITION_TYPE_BUY, mOrderSize, mTradeComment, mMagic);
	mSellLeg			=	new CLeg(symbol, mMultiplierFactor, mLevelSize, POSITION_TYPE_SELL, mOrderSize, mTradeComment, mMagic);
	
	mInitResult		=	INIT_SUCCEEDED;
	
}


CExpertGrid::~CExpertGrid() {

	delete	mBuyLeg;
	delete	mSellLeg;
	
}

void		CExpertGrid::Loop() {
   
   mBuyLeg.SetProfitToClose(mProfitToClose);
   mSellLeg.SetProfitToClose(mProfitToClose);
   
	if(mTradeMode == Buy_and_Sell || mTradeMode == BuyOnly)	   mBuyLeg.OnTick();
	if(mTradeMode  == Buy_and_Sell || mTradeMode == SellOnly)	mSellLeg.OnTick();   
	
}


	
