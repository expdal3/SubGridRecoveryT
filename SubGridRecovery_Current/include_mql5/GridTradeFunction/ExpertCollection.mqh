/*

	GridTrader Collection
	Expert
	
	Copyright 2022, Orchard Forex
	https://www.orchardforex.com

*/

#include "ExpertCustom.mqh"
#include <Blues/StrategyInputClass.mqh>


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
	double   mLevelPoints;                                         //gap in points between level (this need to be processed further into Price for different pair)
	double   mOrderSize;
	string   mTradeComment;
   
	ENUM_TRADE_MODES mTradeMode;
   
   int      mFirstTime;
   bool      mDebug;
public:

	CExpertCollection(string symbolStringList,string suffix,string magicStringList
	                  ,double multiplyFactor,	double profitToClose,int levelPoints,double orderSize, string tradeComment, ENUM_TRADE_MODES tradeMode
				         ,bool debug);
	~CExpertCollection();
   
   void        OnTick();
   void        Setup();
   void        SetTradeMode(ENUM_TRADE_MODES tradeMode){mTradeMode = tradeMode; return;};
   void        SplitSymbolStringList();
   void        SplitMagicStringList();
   void        CombineSymbolAndMagicPair();
   void        SetSymbolAndMagicToStruct();
};


CExpertCollection::CExpertCollection(string symbolStringList,string suffix,string magicStringList
      	                        ,double multiplyFactor,	double profitToClose,int levelPoints,double orderSize, string tradeComment, ENUM_TRADE_MODES tradeMode
      				               ,bool debug)
						               :	CExpert("",levelPoints, orderSize, tradeComment, 0) {

	mSymbolStringList =  symbolStringList;
	mSuffix           = suffix;
	mMagicStringList =  magicStringList;
	mLevelPoints		=	levelPoints;
	mMultiplierFactor = multiplyFactor;
   mProfitToClose = profitToClose;
   mOrderSize     = orderSize;
   mTradeComment       = tradeComment;
   mTradeMode     = tradeMode;
   mFirstTime     = true;
   mDebug         = debug;       
	
	mInitResult		=	INIT_SUCCEEDED;
	
}
void		CExpertCollection::OnTick() {
   
   if (mFirstTime == true) 	{Setup(); mFirstTime=false;}
   
   for(int i=0;i<=ArraySize(mPool)-1;i++) mPool[i].Expert.Loop();     //loop through each of the SymbolPair
}



void		CExpertCollection::Setup() {

   mPoolInput = new CStrategyInput(mSymbolStringList, mSuffix, mMagicStringList);
   mPoolInput.GetSymbolMagicStruct(mPool);
    if(mDebug == true) mPoolInput.PrintInput();
   for(int i=0;i<=ArraySize(mPool)-1;i++) {      
   //initial GridExpert object

   mPool[i].Expert = new CExpertGrid(mPool[i].Symbol, mMultiplierFactor, mProfitToClose, mLevelPoints, mOrderSize, mTradeComment, mPool[i].Magic);
   mPool[i].Expert.SetTradeMode(mTradeMode);
   } 
}



CExpertCollection::~CExpertCollection() {

	for(int i=ArraySize(mPool)-1;i>=0;i--) delete	mPool[i].Expert;   

}



	
