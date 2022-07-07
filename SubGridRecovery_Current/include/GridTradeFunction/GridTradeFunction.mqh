/*

	GridTrader v1.mqh
	Copyright 2022, Orchard Forex
	https://www.orchardforex.com

*/


#define FRAMEWORK_VERSION_3_06_BLS
#define FRAMEWORK_VERSION
#include <Orchard/Frameworks/Framework.mqh>


//
//	Inputs
//

//	V1 grid trading is simple, we just need spacing between trades
//		and lot sizes
extern   int		            InpLevelPoints			=	200;						//	Trade gap in points
extern   int                 InpMaxTrades          =  30;             //Max number of trades allowed

extern ENUM_TRADE_MODES    InpTradeMode            = Buy_and_Sell;   // TradeMode  
extern double              InpMinProfit            = 5.00;           // GridTakeProfit 

//	Now some general trading info
extern   double	         InpOrderSize			   =	0.01;					//	Order size
extern   double            InpFactor               =  1.5;               //LotSize Multiplier

extern	string	         InpGridEATradeComment		=	"GridTrader_Martin";	//	Trade comment
extern	int		         InpGridEAMagic					=	1234;				//	Magic number

#include "ExpertCustom.mqh"
#define CExpert   CExpertGrid
CExpert*	GridExpert;
