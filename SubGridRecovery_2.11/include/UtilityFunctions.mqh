//+------------------------------------------------------------------+
//|   UTILITIES functions                                            |
//+------------------------------------------------------------------+
  
bool  IsNewBar(){
   static datetime   currentTime = 0;
   bool result    =  (currentTime!=Time[0]);
   if(result)  currentTime = Time[0];
   return (result);
 
}

//+------------------------------------------------------------------+
//|      PointValue                                                  |
//+------------------------------------------------------------------+
double PointValue(string symbol) {
	double tickSize = MarketInfo(symbol, MODE_TICKSIZE);
	double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
	double point = MarketInfo(symbol, MODE_POINT);
	double ticksPerPoint = tickSize/point;
	double pointValue = tickValue/ticksPerPoint;
   PrintFormat("tickSize=%f, tickValue=%f, point=%f, ticksPerPoint=%f, pointValue=%f", tickSize, tickValue, point, ticksPerPoint, pointValue);
	return(pointValue);
}


//---

/*  
void GetPointSize(){
   MPP=1;
   if((MarketInfo(Symbol(),MODE_DIGITS)==3)||(MarketInfo(Symbol(),MODE_DIGITS)==5))
      MPP=10;
   PT=MarketInfo(Symbol(),MODE_TICKSIZE)*MPP;

}
*/  

//

// Pips, Points conversion for 4 or 5 digit brokers
//
double   PipSize(){return(PipSize(_Symbol));}
double   PipSize(string symbol)  {
   double   point       = MarketInfo(symbol,MODE_POINT);    // for EURUSD return 0.00001
   int      digits      =   (int) MarketInfo(symbol, MODE_DIGITS);
   return   (((digits%2)==1) ? point*10 : point);

}
//---
//---
double   PriceToPips(double price)                 {return(
                                                      (PipSize(_Symbol)!=0) ? price/PipSize(_Symbol): 0
                                                      );}
double   PriceToPips(double price, string symbol)  {return(
                                                      (PipSize(symbol)!=0) ? price/PipSize(symbol): 0
                                                      );}

//+------------------------------------------------------------------+

double   PipsToPrice(double pips)                  {return(pips*PipSize(_Symbol));}
double   PipsToPrice(double pips, string symbol)   {return(pips*PipSize(symbol));} 
//---

double   PointsToPrice(double points)                 {return(points*MarketInfo(_Symbol, MODE_POINT));}
double   PointsToPrice(double points, string symbol)  {return(points*MarketInfo(symbol, MODE_POINT));}