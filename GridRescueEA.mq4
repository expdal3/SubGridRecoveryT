//+------------------------------------------------------------------+
//|                                            SubGridRecoveryEA.mq4 |
//|                                       Copyright 2022, BlueStone. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright           "Copyright 2022, BlueStone."
#property link                "https://www.mql5.com"
#property version             "2.11"
#property description         "EA to rescue Grid / Martingale Drawdown by closing off sub-grid orders"
#property strict

//#define  PRODMODE X       //If this not defined then "include" the GridTradeFunction, esle skip
//#define  _DEBUG   .

//+------------------------------------------------------------------+
//|   EXTERNAL INPUTS                                                |
//+------------------------------------------------------------------+
 
#include "include/GridCollection.mqh"
#include "include/LogsFunction.mqh"
#include <Blues/TradeInfoClass.mqh>
#include <Blues/Credentials.mqh>


extern  string  __0__                                                      = "____ MAIN DRAWDOWN RESCUE SETTINGS _______";
extern bool                             InpRescueAllowed                   = true;           //Allow rescue?
extern string                           InpSymbol                          = "";             //Symbol(s)-separated by comma (,)
extern string                           InpSymbolSuffix                    = "";             //Broker's symbol suffix
extern string                           InpMagicNumber                     = "1234";          //EA Magic number(s) - separated by comma (,)
extern string                           InpTradeComment                    = __FILE__;       //EA Trade comment to rescue
extern  int                             InpLevelToStartRescue              = 4;              // Order To Start Rescue
extern  double                          InpSubGridProfitToClose            = 0.8;              // Sub-grid's Profit to close 
extern  bool                            InpShowPanel                       = false;          // Show Panel?
extern  int                             InpPanelFontSize                   = 8;

extern  string  __1__                                                      = "____ ADVANCED RESCUE OPTIONS_______";
extern  string  __1a__                                                     = "RescueScheme base on number of grid orders:         ";
extern  string  __1b__                                                     = "  (*) _default_: <=4 is 2Node, 5-10 is 3Node        ";
extern  ENUM_BLUES_SUBGRID_MODE_SCHEME  InpRescueScheme                    = _default_;   // Rescue Scheme
extern  string                          InpIterationModeAndProfitToCloseStr= "2:1.25, 3:2.5, 2:2.0, 3:2.0, 3:1, 3:1, 3:0.5, 3:0.5" ;   // Iteration Mode and ProfitToClose (If select RescueScheme = _Iteration_based_)

extern   bool                           InpPanicCloseAllowed               = true;        // Use PanicClose?
extern   int                            InpPanicCloseOrderCount            = 6;           // Num of grid order for PanicClose (0 = disable)
extern   double                         InpPanicCloseMaxDrawdown           = -120;         // MaxDrawdown for PanicClose (0 = disable)
extern   double                         InpPanicCloseMaxLotSize            = 0.1;         // MaxLotSize for PanicClose (0 = disable)
extern   double                         InpPanicCloseProfitToClose         = -1.0;        // Profit level for panic close
extern   int                            InpPanicClosePosOfSecondOrder      = 0;           // Position of 2nd panic order 0=Smallest order, 1= next grid order ...;  
extern   bool                           InpPanicCloseIsDriftProfitAfterEachIteration              = false;      // Reduce/Increase ProfiToClose in subsequent PanicClose;  
extern   double                         InpPanicCloseDriftProfitStep       = 1;       // Step to reduce (-) or increase(+); 
extern   double                         InpPanicCloseDriftLimit            = 4;       // Min/Max Change to stop drift ProfitToClose; 
extern   int                            InpStopPanicAfterNClose            = 6;           // Disable panic close after n time
   
extern  bool                            InpDebug                           = false;
 
extern  string  __3__                                                      = "____ BACKTEST AND DEMO ACCOUNT ONLY_______";
extern bool                             InpOpenNewGridTrade   = false; // Open new grid to test?
#include "include/GridTradeFunction.mqh"  

//+------------------------------------------------------------------+
//|   INTERNAL INPUTS                                                |
//+------------------------------------------------------------------+

//---init object class
CTradeInfo *tradeInfo;
CGridMaster *BuyGrid;
CGridMaster *SellGrid;
CGridCollection *BuyGridCollection;
CGridCollection *SellGridCollection;

//---input for file saving
string                                       inpBuyFileName          = __FILE__ + "BuyGrid";
string                                       inpSellFileName         = __FILE__ + "SellGrid";

//---other internal parameters
double AcctBalance,   AcctEquity;
int _OrdersTotal = 0;
int _inpmagicnumber;
string _inpsymbol;
int   _testeamagic = 1234;
bool isonechart = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- 

   _inpsymbol = (InpSymbol=="") ? Symbol(): InpSymbol;
   Print(GetInputInfo(InpSymbol,SYMBOL));
   Print(GetInputInfo(InpMagicNumber,MAGIC));
   
   isonechart = IsOneChartSetup();
   
   if(inpUnlockPass!=pass)
     {
      if (MessageBox("Incorrect Password!",MB_OK)==1);
      
      return (INIT_FAILED);
   } else{

      AcctBalance=AccountBalance();
      AcctEquity = AccountEquity();
      tradeInfo = new CTradeInfo();
      
      
      if(isonechart==true){
         Print(__FUNCTION__,": IsOneChartSetup = ", IsOneChartSetup());
         BuyGridCollection = new CGridCollection(_inpsymbol,InpSymbolSuffix,InpMagicNumber,OP_BUY,InpLevelToStartRescue,InpRescueScheme, InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment
                                                ,InpPanicCloseOrderCount,InpPanicCloseMaxDrawdown,InpPanicCloseMaxLotSize,InpPanicCloseProfitToClose,InpPanicClosePosOfSecondOrder,InpStopPanicAfterNClose
                                                ,InpPanicCloseIsDriftProfitAfterEachIteration,InpPanicCloseDriftProfitStep,InpPanicCloseDriftLimit
                                                );
         SellGridCollection = new CGridCollection(_inpsymbol,InpSymbolSuffix,InpMagicNumber,OP_SELL,InpLevelToStartRescue,InpRescueScheme, InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment
                                                ,InpPanicCloseOrderCount,InpPanicCloseMaxDrawdown,InpPanicCloseMaxLotSize,InpPanicCloseProfitToClose,InpPanicClosePosOfSecondOrder,InpStopPanicAfterNClose
                                                ,InpPanicCloseIsDriftProfitAfterEachIteration,InpPanicCloseDriftProfitStep,InpPanicCloseDriftLimit
                                                );
         BuyGridCollection.mInfo = new CGridDashboard("BuyGridCollectionDB",CORNER_RIGHT_UPPER,500,15,30,4);
         SellGridCollection.mInfo= new CGridDashboard("SellGridCollectionDB",CORNER_RIGHT_UPPER,10,15,30,4);
         
         if(InpShowPanel==true)
         {
         //--- Loggings Init - Create 2 Collection dashboard

         BuyGridCollection.mInfo.Add("BUY Grids                                           "
                                     ,"Name     Type | Profit | Size | Rescue?(Iter) | Rescue | Panic"
                                     ,InpPanelFontSize);
         SellGridCollection.mInfo.Add("SELL Grids                                         "
                                     ,"Name     Type | Profit | Size | Rescue?(Iter) | Rescue | Panic"
                                     ,InpPanelFontSize);  
         BuyGridCollection.mInfo.mDashboard.SetRowText(4,                                        // if ticket if found to be active, show the grid in panel
                                                   "                                              Count     Count");
         SellGridCollection.mInfo.mDashboard.SetRowText(4,                                        // if ticket if found to be active, show the grid in panel
                                                   "                                              Count     Count");
         
         }else{
            BuyGridCollection.mInfo.mDashboard.DeleteAll();
            SellGridCollection.mInfo.mDashboard.DeleteAll();         
         }
      }else{
         Print(__FUNCTION__,": IsOneChartSetup = ", IsOneChartSetup());
      //--- Declare grid objects
         //StringReplace(InpMagicNumber,",","");                         //make sure no trailing "," if only one magic
         //_inpmagicnumber = StringToInteger(StringTrimRight(StringTrimLeft(StringReplace(InpMagicNumber,",",""))));        //make sure no trailing blank space
         _inpmagicnumber = StringToInteger(StringTrimRight(StringTrimLeft(InpMagicNumber)));        //make sure no trailing blank space
         _inpsymbol = _inpsymbol+InpSymbolSuffix;
         Print(__FUNCTION__,": input magic is", _inpmagicnumber);
         //Print(_inpmagicnumber);
         BuyGrid = new CGridMaster(_inpsymbol,_inpmagicnumber,OP_BUY,InpLevelToStartRescue,InpRescueScheme,InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment);                 // init new Grid objects with the InpMagicNumber
         SellGrid = new CGridMaster(_inpsymbol,_inpmagicnumber,OP_SELL,InpLevelToStartRescue,InpRescueScheme,InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment);                 // init new Grid objects with the InpMagicNumber
         
         BuyGrid.GetPanicCloseParameters(InpPanicCloseOrderCount,InpPanicCloseMaxDrawdown,InpPanicCloseMaxLotSize,InpPanicCloseProfitToClose,InpPanicClosePosOfSecondOrder,InpStopPanicAfterNClose
                                       ,InpPanicCloseIsDriftProfitAfterEachIteration,InpPanicCloseDriftProfitStep,InpPanicCloseDriftLimit);
         SellGrid.GetPanicCloseParameters(InpPanicCloseOrderCount,InpPanicCloseMaxDrawdown,InpPanicCloseMaxLotSize,InpPanicCloseProfitToClose,InpPanicClosePosOfSecondOrder,InpStopPanicAfterNClose
                                       ,InpPanicCloseIsDriftProfitAfterEachIteration,InpPanicCloseDriftProfitStep,InpPanicCloseDriftLimit);

         //PrintFormat(__FUNCTION__+"Grid Symbol: %s, Magic: %d", _inpsymbol, _inpmagicnumber);   
         //--- Loggings Init - Create 2 dashboard
         if(InpShowPanel==true)
         {
         if(InpTradeMode==Buy_and_Sell || InpTradeMode==BuyOnly){   
            BuyGrid.mMasterInfo.Add("BUY MasterGrid"+"                    "+StringFormat("%s:%d",_inpsymbol,_inpmagicnumber)
                                         ,"Ticket   Symbol   Type   LotSize   OpenPrice   Profit   "
                                         ,InpPanelFontSize);
            BuyGrid.mSubInfo.Add("BUY SubGrid                                           "
                                         ,"Ticket   Symbol   Type   LotSize   OpenPrice   Profit   "
                                         ,InpPanelFontSize);
            
            BuyGrid.ShowGridOrdersOnChart();  //pass main orders to Dashboard Sub
   		   BuyGrid.ShowGridOrdersOnChart(BuyGrid.mSubGrid);   //pass subGrid orders to Dashboard Sub
            }
         
         if(InpTradeMode==Buy_and_Sell || InpTradeMode==SellOnly){
            SellGrid.mMasterInfo.Add("SELL MasterGrid"+"                    "+StringFormat("%s:%d",_inpsymbol,_inpmagicnumber)
                                         ,"Ticket   Symbol   Type   LotSize   OpenPrice   Profit   "
                                         ,InpPanelFontSize);
            SellGrid.mSubInfo.Add("SELL SubGrid                                           "
                                         ,"Ticket   Symbol   Type   LotSize   OpenPrice   Profit   "
                                         ,InpPanelFontSize);
            SellGrid.ShowGridOrdersOnChart();  //pass main orders to Dashboard Sub
      		SellGrid.ShowGridOrdersOnChart(SellGrid.mSubGrid);   //pass subGrid orders to Dashboard Sub
                             
            }
         }else{
         BuyGrid.mMasterInfo.mDashboard.DeleteAll();
         BuyGrid.mSubInfo.mDashboard.DeleteAll();         
         SellGrid.mMasterInfo.mDashboard.DeleteAll();
         SellGrid.mSubInfo.mDashboard.DeleteAll();
         }

      }


   //---load data if any
   //if(LoadData(BuyGrid, InpFileName))           //if succefully load data from file, re-fill master grid using the OrderTicket loaded
   //   BuyGrid.RefillGridWithSavedData(BuyGrid.mOrders, BuyGrid.mBinOrders);
   
      //---load data if any
   //if(LoadData(SellGrid, InpFileName))           //if succefully load data from file, re-fill master grid using the OrderTicket loaded
   //   SellGrid.RefillGridWithSavedData(SellGrid.mOrders, SellGrid.mBinOrders);   

   
   }
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   if(reason==REASON_CHARTCLOSE
      ||reason==REASON_CLOSE
      ||reason==REASON_PROGRAM
      ||reason==REASON_REMOVE
      ||reason==REASON_TEMPLATE
      ){
      
         if(IsOneChartSetup())
           {
             BuyGridCollection.mInfo.mDashboard.DeleteAll();
             SellGridCollection.mInfo.mDashboard.DeleteAll();    
           }
           else{
            SaveData(BuyGrid,inpBuyFileName);
            SaveData(SellGrid,inpSellFileName);
      
      
            BuyGrid.mMasterInfo.mDashboard.DeleteAll();
            BuyGrid.mSubInfo.mDashboard.DeleteAll();         
            SellGrid.mMasterInfo.mDashboard.DeleteAll();
            SellGrid.mSubInfo.mDashboard.DeleteAll();

           }
      }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   #ifndef PRODMODE
   STradeSum BuySum;
   STradeSum SellSum;
   // Start martingale trades
   if(InpOpenNewGridTrade)
     {

         GetSum(BuySum,OP_BUY, _testeamagic);
         GetSum(SellSum,OP_SELL, _testeamagic);
   
   if(
      (IsTradeAllowed() && !IsTradeContextBusy()) 
      && (IsTesting() || IsDemo())                  //Only allow open new test trading order if in demo account or backtest
      )         
      {
      switch(InpTradeMode)
        {
         case  Buy_and_Sell:
            OpenGridTrades(BuySum,OP_BUY, _testeamagic, InpTradeComment); 
            OpenGridTrades(SellSum,OP_SELL, _testeamagic, InpTradeComment); 
           break;
         case  BuyOnly:
            OpenGridTrades(BuySum,OP_BUY, _testeamagic, InpTradeComment); 
           break;
         case  SellOnly:
            OpenGridTrades(SellSum,OP_SELL, _testeamagic, InpTradeComment); 
           break;
         default:
           break;
        }
      
      }   
     }
   #endif
   
   if(isonechart)
     {
         BuyGridCollection.RescueGrid(InpRescueAllowed, InpPanicCloseAllowed, InpDebug);
         SellGridCollection.RescueGrid(InpRescueAllowed, InpPanicCloseAllowed, InpDebug);
         if(IsNewBar() || IsNewSession(5) )
           {
            BuyGridCollection.ShowCollectionOrdersOnChart();
            SellGridCollection.ShowCollectionOrdersOnChart();
           }
         
     }  
   else{
         
      if(_OrdersTotal!=OrdersTotal()
         || BuyGrid.IsAGridOrderJustClosed()
         || SellGrid.IsAGridOrderJustClosed()
         )        //Get the latest order info
        {
         _OrdersTotal = OrdersTotal();
         BuyGrid.GetOrdersOpened();           //pass data to Grid array that match magicnumber BuyGrid.mOrders
         SellGrid.GetOrdersOpened();           //pass data to Grid array that match magicnumber SellGrid.mOrders
        }
   
         BuyGrid.GetSubGridOrders();
         BuyGrid.GetGridStats();
         SellGrid.GetSubGridOrders();
         SellGrid.GetGridStats();
      
      //---normal rescue
      if(InpRescueAllowed==true)
        {
         if(BuyGrid.mIsRecovering==true && BuyGrid.CloseSubGrid(BuyGrid.mSubGrid)){
            BuyGrid.mIteration++; 
            BuyGrid.mRescueCount++;
         }
         if(SellGrid.mIsRecovering==true && SellGrid.CloseSubGrid(SellGrid.mSubGrid)){

            SellGrid.mIteration++; 
            SellGrid.mRescueCount++;
         }
        }
      
      //---panic close
      if(InpRescueAllowed==true && InpPanicCloseAllowed==true)
        {
         if(BuyGrid.mIsPanic==true){
            BuyGrid.GetPanicCloseOrders(InpPanicClosePosOfSecondOrder);
            BuyGrid.ClosePanicCloseOrders();
         }
         if(SellGrid.mIsPanic==true){
            SellGrid.GetPanicCloseOrders(InpPanicClosePosOfSecondOrder);
            SellGrid.ClosePanicCloseOrders();
         }
        }

   //Collect data to array
   if(IsNewBar() || IsNewSession(5) )     //trigger if new bar or every 5 seconds
     {
         if(InpShowPanel==true)
           {
            //---BUY GRID
            BuyGrid.ShowGridOrdersOnChart();  //pass main orders to Dashboard Sub
   		   BuyGrid.ShowGridOrdersOnChart(BuyGrid.mSubGrid);   //pass subGrid orders to Dashboard Sub
   
            //---SELL GRID
            SellGrid.ShowGridOrdersOnChart();  //pass main orders to Dashboard Sub
      		SellGrid.ShowGridOrdersOnChart(SellGrid.mSubGrid);   //pass subGrid orders to Dashboard Sub
            }
     }
   }



}

string GetInputInfo(string _input, int type = SYMBOL)
{
   string arr[];
   string suffix;
   string strlist;
   string output;
   int count;

   count = StringSplitToArray(arr,_input,",");
   suffix = InpSymbolSuffix;
   //concaternate
   if(type==SYMBOL)
     {
       if (_input=="") output = "Rescue current chart symbol: " + Symbol();
         else if (count == 1) output = "Rescue " + IntegerToString(count) + " symbol: " + arr[0];
         else if(count > 1)
           {
             for(int i=0;i<count;i++)
            {
               if (i==0) strlist = arr[i]+suffix+",";
               else if (i==count-1 )strlist = strlist + arr[i]+suffix;
               else strlist = strlist + arr[i]+ suffix + ",";
            }
          output = "Rescue " + IntegerToString(count) + " symbol: " + strlist; 
           }
     }
     
   if(type==MAGIC)
     {
       if (_input=="") output = "Rescue manual trade - magic = 0 ";
         else if (count == 1) output = "Rescue " + IntegerToString(count) + " magic: " + arr[0];
         else if(count > 1)
           {
             for(int i=0;i<count;i++)
            {
               if (i==0) strlist = arr[i]+",";
               else if (i==count-1 )strlist = strlist + arr[i];
               else strlist = strlist + arr[i] + ",";
            }
          output = "Rescue " + IntegerToString(count) + " magic: " + strlist; 
           }
     }  

   return (output);
}



//+------------------------------------------------------------------+

bool IsOneChartSetup(){
   bool isonechart = false;
   if(IsMultiPair()
      || IsMultiMagic()
      )
   isonechart= true;
   else isonechart = false;
  
  return (isonechart);             
}

bool  IsMultiPair(){
   string symbolarr[];
   bool ismultipair = false;
   if(StringSplitToArray(symbolarr,InpSymbol,",")>1)
     {
      ismultipair = true;
     } 
   return (ismultipair); 
}

bool  IsMultiMagic(){
   string magicarr[];
   bool ismultimagic = false;
   if(StringSplitToArray(magicarr,InpMagicNumber,",")>1)
     {
      ismultimagic = true;
     } 
   return (ismultimagic); 
}



void AddGridDashboardOnePair(CDashboard &dashboard
                     , string dashboardObjName
                     , string tableheadertxt
                     , string colheadertxt
                     , int txtsize  =  8
                     , int rows = 10
                     , int corner = CORNER_RIGHT_UPPER
                     , int xdist = 400
                     , int ydist =  15
                     , color txtclr =  clrWhite
                     , string txtfont  =  "Arial"

                     ){
   //---

	
	dashboard.AddRow(tableheadertxt, txtclr, txtfont, txtsize);
	dashboard.AddRow("", txtclr, txtfont, txtsize-2);              // row 2 is for display stats
	dashboard.AddRow("", txtclr, txtfont, txtsize-2);              // row 3 is for display stats
	dashboard.AddRow(colheadertxt, txtclr, txtfont, txtsize-2);
	
   //--- Add 10+ blank row to get the space for the list
	for(int i=0;i<rows-1;i++)
	  {
	   dashboard.AddRow("", txtclr, txtfont, txtsize-2);
	  }
}

int LoadData(CGridMaster &grid, string inpfilename){
  string terminal_data_path = TerminalInfoString(TERMINAL_DATA_PATH);
  string filename;
  if(IsTesting()) filename = terminal_data_path + "\\tester\\files\\"+inpfilename+".bin";
  else filename = terminal_data_path + "\\MQL4\\Files\\"+inpfilename+".bin";
  
  string eaname;                    //hold the name of the EA from the file
  string lastsavedtime;             //hold the last time the file was saved   
  int    lastgridsize;              //hold the last gridsize when the file was saved
  filename = StringTrimRight(StringTrimLeft(inpfilename)); 
  //--- check if previously saved bin file of the grid order is existed, if yes, load 
   if(FileIsExist(filename))                                             // checkif file exit in the "Files" folder
      {                                                                  // ||(IsTesting()=true && FileIsExist(inpfilename+"bin")) check if file exist in the tester folder if during testing                    
      PrintFormat("Found file %s ", filename);
       
      int filehandle = FileOpen(filename, FILE_READ|FILE_BIN);
      if(filehandle!=INVALID_HANDLE)
     {
     //--- load struct into the grid array
     //eaname = FileReadString(filehandle,StringLen(__FILE__));
     lastsavedtime = TimeToStr(FileReadInteger(filehandle), TIME_DATE|TIME_SECONDS);
     lastgridsize = FileReadInteger(filehandle); 
     PrintFormat("File metadata - LastSaveTime: %s | LastGridSizeKnown: %d", lastsavedtime, lastgridsize);
     
     //--- load the struct data into array
     if(ArraySize(grid.mBinOrders)<lastgridsize)ArrayResize(grid.mBinOrders,lastgridsize);      //Resize grid array to hold incoming data

     for(int i=0;i<lastgridsize;i++)
      {          
      FileReadStruct(
          filehandle       // File handle
          ,grid.mBinOrders[i]     // link to an object
          //,sizeof(SOrderInfo_BinFormat)
           );
      PrintFormat("...Loading orders ticket %d with seq %d into struct succesfully", grid.mBinOrders[i].Ticket, grid.mBinOrders[i].SequenceNumber );
     
      }
      FileClose(filehandle);
      FileDelete(filename);
      return(1);
     } else { PrintFormat("Failed to open %s file, Error code = %d",filename,GetLastError());}
     } else { PrintFormat("%s file does not exist, Error code = %d",filename,GetLastError());}
  return(0);
}

//---
void SaveData(CGridMaster &grid, string inpfilename){
   grid.ConvertToBinFormat();  // grid.mOrders, grid.mBinOrders transfer orders to Bin-writable format (remove all string variable)
   string terminal_data_path = TerminalInfoString(TERMINAL_DATA_PATH);
   //string filename = terminal_data_path + "\\MQL4\\Files\\"+inpfilename+".bin";
   string filename = StringTrimRight(StringTrimLeft(inpfilename));
   PrintFormat("the file name is %s", filename);               //"C:/Users/ducan/AppData/Roaming/MetaQuotes/Terminal/17B5FF217FE004B792EFA9D824B75EEC/MQL4/Files/SubGridRecoveryFiles/mastegridorders.bin";

   int filehandle = FileOpen(filename,FILE_WRITE|FILE_BIN);

   if(filehandle!=INVALID_HANDLE)
     {
      //--- prepare the counter of the number of bytes
      uint counter=0;
      //FileWrite(filehandle,__FILE__);
      FileWriteInteger(filehandle,(int)TimeCurrent());
      FileWriteInteger(filehandle,grid.mSize);
      PrintFormat("Current grid.mSize written to file is %d", grid.mSize );
           
      for(int i=0;i<grid.mSize;i++)
        {         
         PrintFormat("...Writing order ticket %d to file",grid.mBinOrders[i].Ticket);
         uint byteswritten=FileWriteStruct(
                filehandle       // File handle
                ,grid.mBinOrders[i]     // link to an object
                  );
      
       
       //--- check the number of bytes written
       
         if(byteswritten!=sizeof(SOrderInfo_BinFormat))
           {
            PrintFormat("Error read data. Error code=%d",GetLastError());
            //--- close the file
            FileClose(filehandle);
            return;
           }
         else counter+=byteswritten;
         }
     //--- close the file
     FileClose(filehandle);                 
     }

     else { PrintFormat("Failed to open %s file, Error code = %d",filename,GetLastError());}
     
     //---for testing mode

     #ifndef PRODMODE
     if(IsTesting()){
     Print("EA is in Testing mode: ", (bool)IsTesting());
     Print("src file ",terminal_data_path+"\\tester\\files\\"+filename);
     Print("dst file ",terminal_data_path+"\\MQL4\\Files\\"+filename);
     string src_file_path = terminal_data_path+"\\tester\\files\\"+filename;
     string dst_file_path = terminal_data_path+"\\MQL4\\Files\\"+filename;
     if(!FileCopy(src_file_path,0,dst_file_path,FILE_REWRITE))PrintFormat("File copy failed! Error code=%d",GetLastError());
     }
     #endif 
     
}


