/*

	GridTrader v1
	Expert
	
	Copyright 2022, Orchard Forex
	https://www.orchardforex.com

*/

#include <Orchard/Frameworks/Framework.mqh>
#include "Expert.mqh"
#include "Leg.mqh"

class CExpertGrid : public CExpert {

protected:
   CLeg*    mBuyLeg;
   CLeg*    mSellLeg;
	double	mMultiplierFactor;                                    //FactorMultipler
	double   mProfitToClose;
	ENUM_TRADE_MODES mTradeMode;

public:

	CExpertGrid(double multiplyFactor,	double profitToClose,
	         int levelPoints,                    //add the new 'factor' parameter
				double orderSize, string tradeComment, long magic);
	~CExpertGrid();
   
   void        Loop();
   void        SetTradeMode(ENUM_TRADE_MODES tradeMode){mTradeMode = tradeMode; return;};
};


CExpertGrid::CExpertGrid(double multiplyFactor, double profitToClose, int levelPoints, double orderSize, string tradeComment, long magic)
						:	CExpert(levelPoints, orderSize, tradeComment, magic) {

	mLevelSize		=	PointsToDouble(levelPoints);
	mMultiplierFactor = multiplyFactor;
   mProfitToClose = profitToClose;

	mBuyLeg			=	new CLeg(mMultiplierFactor, mLevelSize, POSITION_TYPE_BUY, mOrderSize, mTradeComment, mMagic);
	mSellLeg			=	new CLeg(mMultiplierFactor, mLevelSize, POSITION_TYPE_SELL, mOrderSize, mTradeComment, mMagic);
	
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


	
