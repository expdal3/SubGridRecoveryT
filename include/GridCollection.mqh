//--- includes
#include "GridOrderManagement.mqh"

struct SGridCollectionId
  {
   string   sSymbol;
   int      sMagic;
   
  };

class CGridCollection
  {
public:
   CGridMaster          *mGridCollection[];        // arrays to hold multiple grid with different symbols and magicnumber

   SGridCollectionId    mGridSymbolMagic[];           //
   string               mMagicNumberStringList;       // StringList of Magicnumber from user input
   string               mSymbolStringList;            // StringList of Symbol name from user input
   string               mSymbolSuffix;                // SymbolSuffix - provided by user

//---Dashboard object
   CGridDashboard       *mInfo;


protected:
   string               mMagicNumbers[];              // StringArray to hold multiple magic number splitted from mMagicNumberStringList
   string               mSymbols[];                   // StringArray to hold multiple symbol name splitted from mSymbolStringList
   string               mSymbolMagicPairs[];

  
public:
                     CGridCollection(string symbolstrlist, string symbolsuffix,string magicnumberstrlist
                                    ,int ordertype, int levelstartrescue, ENUM_BLUES_SUBGRID_MODE_SCHEME rescuescheme, double profittoclose, string iterationinput, string comment
                                    ,int panicordercount, double panicmaxdd, double panicmaxlotsize, double panicprofittoclose,int panicsecondpos, int panicnstop, bool panicisdrift, double panicdriftstep, double panicdriftlimit
                                    )
                                    :mSymbolStringList(symbolstrlist)
                                    ,mSymbolSuffix(symbolsuffix)
                                    ,mMagicNumberStringList(magicnumberstrlist) 
                                    {Init(ordertype, levelstartrescue,rescuescheme,profittoclose,iterationinput,comment,panicordercount,panicmaxdd,panicmaxlotsize, panicprofittoclose, panicsecondpos, panicnstop, panicisdrift, panicdriftstep,panicdriftlimit);};
                    ~CGridCollection(void);
                    int    Init(int ordertype,int levelstartrescue, ENUM_BLUES_SUBGRID_MODE_SCHEME rescuescheme, double profittoclose, string iterationinput, string comment
                                ,int panicordercount, double panicmaxdd, double panicmaxlotsize, double panicprofittoclose,int panicsecondpos, int panicnstop, bool panicisdrift, double panicdriftstep, double panicdriftlimit);
                    void   RescueGrid(bool rescueallow, bool paniccloseallow);
                    
                    void   ShowCollectionOrdersOnChart();

protected:                    
                    void   ReadSymbolStringList();
                    void   ReadMagicNumberStringList();
                    void   CombineSymbolAndMagicPair();
                    void   ReadSymbolAndMagicToStruct();
};


int  CGridCollection::Init(int ordertype, int levelstartrescue, ENUM_BLUES_SUBGRID_MODE_SCHEME rescuescheme, double profittoclose, string iterationinput, string comment
                           ,int panicordercount, double panicmaxdd, double panicmaxlotsize, double panicprofittoclose, int panicsecondpos, int panicnstop, bool panicisdrift, double panicdriftstep, double panicdriftlimit){
      ReadSymbolStringList();                                  //mSymbolStringList
      ReadMagicNumberStringList();                             //mMagicNumberStringList
      CombineSymbolAndMagicPair();
      ReadSymbolAndMagicToStruct();
      string symbol="";
      int    magic=0;
      
      ArrayResize(mGridCollection, 1);
      //ArrayResize(mSellGridCollection, 1);
      for(int i=0;i<ArraySize(mGridSymbolMagic);i++)
        {
         //Read the symbol and magicnumber from mSymbolMagicPairs array
         symbol = mGridSymbolMagic[i].sSymbol;
         magic = StringToInteger(mGridSymbolMagic[i].sMagic);
         mGridCollection[0] = new CGridMaster(symbol,magic,ordertype,levelstartrescue,rescuescheme, profittoclose,iterationinput,comment);      //initialize Buy Grid
         mGridCollection[0].GetPanicCloseParameters(panicordercount,panicmaxdd,panicmaxlotsize,panicprofittoclose,panicsecondpos,panicnstop,panicisdrift, panicdriftstep,panicdriftlimit);                       //load in panicclose parameters
         InsertIndexToArray(mGridCollection);
        }
      RemoveIndexFromArray(mGridCollection,0);      
      
     // mInfo = new CGridDashboard("GridCollectionDB",CORNER_RIGHT_UPPER,400,15,30,3);
      
      for(int i=0;i<ArraySize(mGridCollection);i++)
        {PrintFormat(__FUNCTION__+" GridName: %s, Type: %s",mGridCollection[i].mGridName,OrderTypeName(mGridCollection[i].mOrderType));
        }
      
      return(INIT_SUCCEEDED);
}

void  CGridCollection::RescueGrid(bool rescueallow, bool paniccloseallow){
      

     for(int i=0;i<ArraySize(mGridCollection);i++)
       {
        
        if(mGridCollection[i].mSymbolMagicTypeOrdersTotal!=mGridCollection[i].GetSymbolMagicTypeOrdersTotal()  //if number of opened order changed
            || mGridCollection[i].IsAGridOrderJustClosed()                                                     //handle partial close event

         )        
        {
         mGridCollection[i].mSymbolMagicTypeOrdersTotal=mGridCollection[i].GetSymbolMagicTypeOrdersTotal();
         mGridCollection[i].GetOrdersOpened();           //pass data to Grid array that match symbol, magicnumber, ordertype
        }
   
         mGridCollection[i].GetSubGridOrders();
         mGridCollection[i].GetGridStats();

      //---normal rescue
      if(rescueallow==true && mGridCollection[i].mIsRecovering==true){
         if(mGridCollection[i].CloseSubGrid(mGridCollection[i].mSubGrid)){
            mGridCollection[i].mIteration++; 
            mGridCollection[i].mRescueCount++;
         }}
         
      //--- panic close
      if(rescueallow==true && paniccloseallow==true && mGridCollection[i].mIsPanic==true){
         mGridCollection[i].GetPanicCloseOrders(mGridCollection[i].mPanicCloseSecondOrderPos);
         mGridCollection[i].ClosePanicCloseOrders(); 
         }
       
       }
      
}

void  CGridCollection::ReadSymbolStringList(){
   if(StringSplitToArray(mSymbols, mSymbolStringList,",")>0){
      for(int i=0;i<ArraySize(mSymbols);i++)
        {
         mSymbols[i] = mSymbols[i]+mSymbolSuffix;              
         StringTrimRight(StringTrimLeft(mSymbols[i]));
        }
   }
}

void  CGridCollection::ReadMagicNumberStringList(){
   if(StringSplitToArray(mMagicNumbers, mMagicNumberStringList,",")>0){
      for(int i=0;i<ArraySize(mMagicNumbers);i++)
        {
         StringTrimRight(StringTrimLeft(mMagicNumbers[i]));
        }
   }
}

void CGridCollection::CombineSymbolAndMagicPair(){
      ArrayResize(mSymbolMagicPairs,1);
      for(int sym=0;sym<ArraySize(mSymbols);sym++)
        {
         for(int maj=0;maj<ArraySize(mMagicNumbers);maj++)
           {
            //combine
            mSymbolMagicPairs[0] = mSymbols[sym]+":"+mMagicNumbers[maj];
            InsertIndexToArray(mSymbolMagicPairs);
           }
        }
        RemoveIndexFromArray(mSymbolMagicPairs,0);

}

void  CGridCollection::ReadSymbolAndMagicToStruct(){
      int sep_pos;
      ArrayResize(mGridSymbolMagic,ArraySize(mSymbolMagicPairs));
      for(int i=0;i<ArraySize(mGridSymbolMagic);i++)
        {
         StringTrimRight(StringTrimLeft(mSymbolMagicPairs[i]));             // make sure no trailing blank
         sep_pos = StringFind(mSymbolMagicPairs[i],":");
         if(sep_pos>=0){
            mGridSymbolMagic[i].sSymbol = StringSubstr(mSymbolMagicPairs[i],0,sep_pos);
            mGridSymbolMagic[i].sMagic = StringToInteger(StringSubstr(mSymbolMagicPairs[i],sep_pos+1));
         }
         else continue;   
        }
}

void CGridCollection::ShowCollectionOrdersOnChart(){

   int _headerrowstoskip = mInfo.mHeaderRowsToSkip;
   bool  gridisactive = false;
   string blank = "--";
   string _last3digitmagic;
   int magiclen;
   int substrpos;
   //--- update row text
   for(int x=0;x<ArraySize(mGridCollection);x++)
	  {
	  
	   magiclen = StringLen(IntegerToString(mGridCollection[x].mMagicNumber));
	   for(int i=0;i<mGridCollection[x].mSize;i++)
	     {
	      if(OrderSelect(mGridCollection[x].mOrders[i].Ticket,SELECT_BY_TICKET,MODE_TRADES))        //search if any the grids order ticket is found in OrdersTotal
	      {
            gridisactive = true;
            break;
	      }
	     }

      if(gridisactive==true && mGridCollection[x].mSize !=0)
      {
         
         if(magiclen <=3) substrpos = 0;            
         else if (magiclen < 6) substrpos = magiclen -  (magiclen % 3);
         else substrpos = magiclen - 3;
         _last3digitmagic = StringSubstr(IntegerToString(mGridCollection[x].mMagicNumber),substrpos);
                                       
         Print(_last3digitmagic);                              
	      mInfo.mDashboard.SetRowText(x+_headerrowstoskip+1,                                        // if ticket if found to be active, show the grid in panel
	                                 StringFormat("%s    %s  %.2f   %d   %s   (%d)   %d   %d" 
	                                               ,mGridCollection[x].mSymbol+"xx"+_last3digitmagic
	                                               ,OrderTypeName(mGridCollection[x].mOrderType)
	                                               ,mGridCollection[x].mProfit
	                                               ,mGridCollection[x].mSize
	                                               ,(string) mGridCollection[x].mIsRecovering
	                                               ,mGridCollection[x].mIteration
	                                               ,mGridCollection[x].mRescueCount
	                                               ,mGridCollection[x].mPanicCloseRescueCount
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
    }

}