/*

	GridTrader v1
	Expert
	
	Copyright 2022, Orchard Forex
	remember to replace this file with future update from Orchard
	https://www.orchardforex.com

*/

#include <Orchard/Frameworks/Framework.mqh>
#include "Leg.mqh"

class CExpert : public CExpertBase {

protected:
   
	CLeg*						mBuyLeg;
	CLeg*						mSellLeg;

protected:
   
	double	mLevelSize;
	
	virtual void		Loop();

public:

	CExpert(	string symbol, int levelPoints,
				double orderSize, string tradeComment, long magic);
	~CExpert();

};


CExpert::CExpert(string symbol, int levelPoints, double orderSize, string tradeComment, long magic)
						:	CExpertBase(symbol, orderSize, tradeComment, magic) {

	mLevelSize		=	PointsToDouble(symbol, levelPoints);

	mBuyLeg			=	new CLeg(symbol,1,mLevelSize, POSITION_TYPE_BUY, mOrderSize, mTradeComment, mMagic);
	mSellLeg			=	new CLeg(symbol,1,mLevelSize, POSITION_TYPE_SELL, mOrderSize, mTradeComment, mMagic);
	
	mInitResult		=	INIT_SUCCEEDED;
	
}

CExpert::~CExpert() {

	delete	mBuyLeg;
	delete	mSellLeg;
	
}

void		CExpert::Loop() {

	mBuyLeg.OnTick();
	mSellLeg.OnTick();
	
}
	
