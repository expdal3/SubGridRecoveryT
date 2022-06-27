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
   

protected:
   string               mMagicNumbers[];              // StringArray to hold multiple magic number splitted from mMagicNumberStringList
   string               mSymbols[];                   // StringArray to hold multiple symbol name splitted from mSymbolStringList
   string               mSymbolMagicPairs[];

  
public:
                     CGridCollection(string symbolstrlist, string symbolsuffix,string magicnumberstrlist
                                    ,int ordertype, int levelstartrescue, ENUM_BLUES_SUBGRID_MODE_SCHEME rescuescheme, double profittoclose, string iterationinput, string comment
                                    )
                                    :mSymbolStringList(symbolstrlist)
                                    ,mSymbolSuffix(symbolsuffix)
                                    ,mMagicNumberStringList(magicnumberstrlist) 
                                    {Init(ordertype, levelstartrescue,rescuescheme,profittoclose,iterationinput,comment);};
                    ~CGridCollection(void);
                    int    Init(int ordertype,int levelstartrescue, ENUM_BLUES_SUBGRID_MODE_SCHEME rescuescheme, double profittoclose, string iterationinput, string comment);
                    void   RescueGrid();

protected:                    
                    void   ReadSymbolStringList();
                    void   ReadMagicNumberStringList();
                    void   CombineSymbolAndMagicPair();
                    void   ReadSymbolAndMagicToStruct();
};


int  CGridCollection::Init(int ordertype, int levelstartrescue, ENUM_BLUES_SUBGRID_MODE_SCHEME rescuescheme, double profittoclose, string iterationinput, string comment){
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

         InsertIndexToArray(mGridCollection);
        }
      RemoveIndexFromArray(mGridCollection,0);      
      
      for(int i=0;i<ArraySize(mGridCollection);i++)
        {PrintFormat(__FUNCTION__+" GridName: %s, Type: %s",mGridCollection[i].mGridName,OrderTypeName(mGridCollection[i].mOrderType));
        }
      
      return(INIT_SUCCEEDED);
}

void  CGridCollection::RescueGrid(){
         //Get the latest order info
      Print("Operate Rescue grid go here");
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