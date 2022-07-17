/*

	GridTrader v1
	Expert
	
	Copyright 2022, Orchard Forex
	https://www.orchardforex.com

*/

#include <Orchard/Frameworks/Framework.mqh>

struct SLegStat
  {
   double   Profit;           //Leg basket profit
   double   TrailOrderSize;   //Leg basket trail OrderSize
  };

class CLeg : public CLegBase {

private:

	double					mLevelSize;

	int						mCount;
	double					mEntry;
	double					mExit;
	
	void						CloseLevel(double price);        //Close one Level of the leg
	void						OpenTrade(double price);
	void						Recount();
protected:
	void						Loop();
	
   //---BlueStone Extension
	
private:
   string               mSymbol;                         //this enable multipair trading	
   double               mMultiplyFactor;                 //Multiply factor for order size
   SLegStat             mLegStat;
   bool                 mTieBreak;                       //TieBreak when lotsize = 0.01
   void						CloseAll();
   double               mProfitToClose;
//---
	
public:

	CLeg(string symbol, 	double multiplyFactor                              // (multiplyFactor is added)
	      , double levelSize,
			ENUM_POSITION_TYPE legType,
			double orderSize, string tradeComment, long magic);

   void SetProfitToClose(double profitToClose){mProfitToClose = profitToClose; return;};

};

CLeg::CLeg(string symbol, double multiplyFactor, double levelSize,
			ENUM_POSITION_TYPE legType,
			double orderSize, string tradeComment, long magic)
			: CLegBase(symbol, legType, orderSize, tradeComment, magic) {
   
   mSymbol = symbol;
	mLevelSize		=	levelSize;
   mMultiplyFactor		=	multiplyFactor;
   
	Recount();

}



void	CLeg::Loop() {

	//	First process the closing rules
	//	On the first run there may be no trades but there is no harm
	//if (mLegType==POSITION_TYPE_BUY && mLastTick.bid>=mExit)	{
	//	CloseLevel(mLastTick.bid);
	//} else
	//if (mLegType==POSITION_TYPE_SELL && mLastTick.ask<=mExit)	{
	//	CloseLevel(mLastTick.ask);
	//}
	Recount();
   //PrintFormat(__FUNCTION__+"mLegStat.Profit: %.2f, mProfitToClose: %.2f", mLegStat.Profit, mProfitToClose);
   //--- BLS Extension
	//	On the first run there may be no trades but there is no harm
	if (mLegStat.Profit>mProfitToClose)	{
		CloseAll();
	}
   
   //__DEBUG__
   //PrintFormat(__FUNCTION__+"%s (mCount==0: %s || mLastTick.ask<=mEntry: %s)",mSymbol, (string) (mCount==0), (string)(mLastTick.ask<=mEntry));
   //PrintFormat(__FUNCTION__+"%s CurrentAsk: %.5f, mEntry:  %.5f, mLastTick.ask: %.5f)",mSymbol, SymbolInfoDouble(mSymbol,SYMBOL_ASK), mEntry, mLastTick.ask);
   //PrintFormat(__FUNCTION__+"%s mLegType: %s:  %s)",mSymbol, (string) mLegType, (string) (mLegType==POSITION_TYPE_BUY));
	
	//	Finally the new trade entries
	if (mLegType==POSITION_TYPE_BUY) {
		if (mCount==0 || mLastTick.ask<=mEntry) {
      //PrintFormat(__FUNCTION__+"%s OpenTrade at mLastTick.ask: %.2f",mSymbol, mLastTick.ask);
		OpenTrade(mLastTick.ask);
		}	
	} else {
		if (mCount==0 || mLastTick.bid>=mEntry) {
			OpenTrade(mLastTick.bid);
		}	
	}

}

void	CLeg::CloseLevel(double price) {

	for (int i=PositionInfo.Total()-1; i>=0; i--) {
		
		if (!PositionInfo.SelectByIndex(i)) continue;
		if (PositionInfo.Symbol()!=mSymbol || PositionInfo.Magic()!=mMagic || PositionInfo.PositionType()!=mLegType) continue;
		
		int	ticket	=	(int)PositionInfo.Ticket();
	
		if (PositionInfo.PositionType()==POSITION_TYPE_BUY && (price-mLevelSize)>=PositionInfo.PriceOpen()) {
			Trade.PositionClose(ticket);
			continue;
		}
		
		if (PositionInfo.PositionType()==POSITION_TYPE_SELL && (price+mLevelSize)<=PositionInfo.PriceOpen()) {
			Trade.PositionClose(ticket);
			continue;
		}

	}
	Recount();

}

void	CLeg::OpenTrade(double price) {
   
   double _lot = (mCount==0)?
                        mOrderSize:
                        mLegStat.TrailOrderSize*mMultiplyFactor;
	
	double _incre = 0.0;                     
   if(mTieBreak==true && mMultiplyFactor>1)
     {
      _incre = SymbolInfoDouble(mSymbol,SYMBOL_VOLUME_MIN);
      _lot += _incre;   //add tiebreak
      mTieBreak=false;
     }
	
	#ifdef __MQL5__
	   _lot = LotAdjuster(_lot);
	#endif 

	Trade.PositionOpen(mSymbol, (ENUM_ORDER_TYPE)mLegType, _lot, price, 0, 0, mTradeComment);       //_lot replace mOrderSize which from CExpertBase
	Recount();

}


/*
 *	Recount()
 *
 *	Mainly for restarts
 *	Scans currently open trades and rebuilds the position
 */
void		CLeg::Recount() {

	mCount					=	0;
	mEntry					=	0;
	mExit						=	0;
	
	//---BLS extension
	mLegStat.Profit      = 0;
	mLegStat.TrailOrderSize = 0;
	
	mTieBreak            =  false;
	//---
	
	double	high			=	0;
	double	low			=	0;
	
	double	lead			=	0;
	double	trail			=	0;

	for (int i=PositionInfo.Total()-1; i>=0; i--) {
		
		if (!PositionInfo.SelectByIndex(i)) continue;
		
		else if (PositionInfo.Symbol()!=mSymbol || PositionInfo.Magic()!=mMagic || PositionInfo.PositionType()!=mLegType) continue;
      else{
      

		mCount++;
		if (high==0 || PositionInfo.PriceOpen()>high)		high	=	PositionInfo.PriceOpen();
		if (low==0 || PositionInfo.PriceOpen()<low)		low	=	PositionInfo.PriceOpen();
      
      //---collect basket profit
       mLegStat.Profit  += PositionInfo.Profit()+PositionInfo.Swap()+PositionInfo.Commission();

      //---collect basket trailing orderSize

       if(mLegStat.TrailOrderSize==PositionInfo.Volume() && mMultiplyFactor>1.00)         //tiebreaker
            {
               mTieBreak=true;
            }else{
            if(mLegStat.TrailOrderSize==0 || mLegStat.TrailOrderSize<PositionInfo.Volume())     // first order of the basket
               {
                mLegStat.TrailOrderSize=PositionInfo.Volume();
               }
                  mTieBreak=false;
               }
      }        
	}

	if (mCount>0) {
		if (mLegType==POSITION_TYPE_BUY) {
			mEntry	=	low-mLevelSize;
			mExit		=	low+mLevelSize;
		} else {
			mEntry	=	high+mLevelSize;
			mExit		=	high-mLevelSize;
		}
	}

}



//---BLS Extension

void     CLeg::CloseAll(){
	for (int i=PositionInfo.Total()-1; i>=0; i--) {
		
		if (!PositionInfo.SelectByIndex(i)) continue;
		if (PositionInfo.Symbol()!=mSymbol || PositionInfo.Magic()!=mMagic || PositionInfo.PositionType()!=mLegType) continue;
		
		int	ticket	=	(int)PositionInfo.Ticket();
	
		if (
		   PositionInfo.Symbol() == mSymbol
		   && PositionInfo.PositionType()==mLegType 
		   && PositionInfo.Magic()==mMagic
		   ) {
			Trade.PositionClose(ticket);
			continue;
		}	
	}
	Recount();

}