//+------------------------------------------------------------------+
//|                                            SubGridRecoveryEA.mq4 |
//|                                       Copyright 2022, BlueStone. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright           "Copyright 2022, BlueStone."
#property link                "https://www.mql5.com"
#property version             "2.04"
#property description         "EA to rescue Grid / Martingale Drawdown by closing off sub-grid orders"
#property strict

//#define  PRODMODE X       //If this not defined then "include" the GridTradeFunction, esle skip

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
extern string                           InpMagicNumber                     = "1111";          //EA Magic number(s) - separated by comma (,)
extern string                           InpTradeComment                    = __FILE__;       //EA Trade comment to rescue
extern  int                             InpLevelToStartRescue              = 4;              // Order To Start Rescue
extern  double                          InpSubGridProfitToClose            = 1;              // Sub-grid's Profit to close 
extern  bool                            InpShowPanel                       = false;          // Show Panel?
extern  int                             InpPanelFontSize                   = 10;

extern  string  __1__                                                      = "____ ADVANCED RESCUE OPTIONS_______";
extern  string  __1a__                                                     = "RescueScheme base on number of grid orders:         ";
extern  string  __1b__                                                     = "  (*) _default_: <=4 is 2Node, 5-10 is 3Node        ";
extern  ENUM_BLUES_SUBGRID_MODE_SCHEME  InpRescueScheme                    = _default_;   // Rescue Scheme
extern  string                          InpIterationModeAndProfitToCloseStr= "2:1.25, 3:2.5, 2:2.0, 3:2.0, 3:1, 3:1, 3:0.5, 3:0.5" ;   // Iteration Mode and ProfitToClose (If select RescueScheme = _Iteration_based_)

extern  string  __2__                                                      = "____ BACKTEST AND DEMO ACCOUNT ONLY_______";
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
int _magicnumber;
string _inpsymbol;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- 
   _inpsymbol = (InpSymbol=="") ? Symbol(): InpSymbol;

   if(inpUnlockPass!=pass)
     {
      if (MessageBox("Incorrect Password!",MB_OK)==1);
      
      return (INIT_FAILED);
   } else{

      AcctBalance=AccountBalance();
      AcctEquity = AccountEquity();
      tradeInfo = new CTradeInfo();
      
      
      if(IsOneChartSetup()==true){
         BuyGridCollection = new CGridCollection(_inpsymbol,InpSymbolSuffix,InpMagicNumber,OP_BUY,InpLevelToStartRescue,InpRescueScheme, InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment);
         SellGridCollection = new CGridCollection(_inpsymbol,InpSymbolSuffix,InpMagicNumber,OP_SELL,InpLevelToStartRescue,InpRescueScheme, InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment);
         BuyGridCollection.mInfo = new CGridDashboard("BuyGridCollectionDB",CORNER_RIGHT_UPPER,600,15,30,3);
         SellGridCollection.mInfo= new CGridDashboard("SellGridCollectionDB",CORNER_RIGHT_UPPER,3,15,30,3);
         Print(__FUNCTION__,"IsOneChartSetup = ", IsOneChartSetup());
         
         if(InpShowPanel==true)
         {
         //--- Loggings Init - Create 2 Collection dashboard

         BuyGridCollection.mInfo.Add("BUY Grids                                           "
                                     ,"Name          Type        Profit  Size   BeingRescued?   Iteration    RescueCount   "
                                     ,InpPanelFontSize);
         SellGridCollection.mInfo.Add("SELL Grids                                           "
                                     ,"Name          Type        Profit  Size   BeingRescued?   Iteration    RescueCount   "
                                     ,InpPanelFontSize);  
         }else{
            BuyGridCollection.mInfo.mDashboard.DeleteAll();
            SellGridCollection.mInfo.mDashboard.DeleteAll();         
         }
      }else{
      //--- Declare grid objects
         //StringReplace(InpMagicNumber,",","");                         //make sure no trailing "," if only one magic
         _magicnumber = StringToInteger(StringTrimRight(StringTrimLeft(StringReplace(InpMagicNumber,",",""))));        //make sure no trailing blank space
         BuyGrid = new CGridMaster(_inpsymbol,_magicnumber,OP_BUY,InpLevelToStartRescue,InpRescueScheme,InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment);                 // init new Grid objects with the InpMagicNumber
         SellGrid = new CGridMaster(_inpsymbol,_magicnumber,OP_SELL,InpLevelToStartRescue,InpRescueScheme,InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment);                 // init new Grid objects with the InpMagicNumber
         Print(__FUNCTION__,"IsOneChartSetup = ", IsOneChartSetup());
   
         //--- Loggings Init - Create 2 dashboard
         if(InpShowPanel==true)
         {
         if(InpTradeMode==Buy_and_Sell || InpTradeMode==BuyOnly){   
            BuyGrid.mMasterInfo.Add("BUY MasterGrid                                           "
                                         ,"Ticket   Symbol   Type   LotSize   OpenPrice   Profit   "
                                         ,InpPanelFontSize);
            BuyGrid.mSubInfo.Add("BUY SubGrid                                           "
                                         ,"Ticket   Symbol   Type   LotSize   OpenPrice   Profit   "
                                         ,InpPanelFontSize);
            
            BuyGrid.ShowGridOrdersOnChart();  //pass main orders to Dashboard Sub
   		   BuyGrid.ShowGridOrdersOnChart(BuyGrid.mSubGrid);   //pass subGrid orders to Dashboard Sub
            }
         
         if(InpTradeMode==Buy_and_Sell || InpTradeMode==SellOnly){
            SellGrid.mMasterInfo.Add("SELL MasterGrid                                           "
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

         GetSum(BuySum,OP_BUY, _magicnumber);
         GetSum(SellSum,OP_SELL, _magicnumber);
   
   if(
      (IsTradeAllowed() && !IsTradeContextBusy()) 
      && (IsTesting() || IsDemo())                  //Only allow open new test trading order if in demo account or backtest
      )         
      {
      switch(InpTradeMode)
        {
         case  Buy_and_Sell:
            OpenGridTrades(BuySum,OP_BUY, _magicnumber, InpTradeComment); 
            OpenGridTrades(SellSum,OP_SELL, _magicnumber, InpTradeComment); 
           break;
         case  BuyOnly:
            OpenGridTrades(BuySum,OP_BUY, _magicnumber, InpTradeComment); 
           break;
         case  SellOnly:
            OpenGridTrades(SellSum,OP_SELL, _magicnumber, InpTradeComment); 
           break;
         default:
           break;
        }
      
      }   
     }
   #endif
   
   if(IsOneChartSetup())
     {
         BuyGridCollection.RescueGrid(InpRescueAllowed);
         SellGridCollection.RescueGrid(InpRescueAllowed);
         if(IsNewBar())
           {
            BuyGridCollection.ShowCollectionOrdersOnChart();
            SellGridCollection.ShowCollectionOrdersOnChart();
           }
         
     }  
   else{
         
      if(_OrdersTotal!=OrdersTotal())        //Get the latest order info
        {
         _OrdersTotal = OrdersTotal();
         BuyGrid.GetOrdersOpened();           //pass data to Grid array that match magicnumber BuyGrid.mOrders
         SellGrid.GetOrdersOpened();           //pass data to Grid array that match magicnumber SellGrid.mOrders
        }
   
         BuyGrid.GetSubGridOrders();
         BuyGrid.GetGridStats();
         SellGrid.GetSubGridOrders();
         SellGrid.GetGridStats();
      
      if(InpRescueAllowed==true)
        {
         if(BuyGrid.mIsRecovering==true){
            if(BuyGrid.CloseSubGrid(BuyGrid.mSubGrid)){
            BuyGrid.mIteration++; 
            BuyGrid.mRescueCount++;
         }}
         if(SellGrid.mIsRecovering==true){
            if(SellGrid.CloseSubGrid(SellGrid.mSubGrid)){
            SellGrid.mIteration++; 
            SellGrid.mRescueCount++;
         }}
        }

   //Collect data to array
   if(IsNewBar() )
     {
         if(InpShowPanel==true)
           {
            //---BUY GRID
            //Print(__FUNCTION__,"NUmber of opned buy order is: ", BuyGrid.CountOrder(TYPE,BuyGrid.mOrderType,MODE_TRADES));
            //Print("BuyGrid ArraySize is ", ArraySize(BuyGrid.mOrders) );
            BuyGrid.ShowGridOrdersOnChart();  //pass main orders to Dashboard Sub
   		   BuyGrid.ShowGridOrdersOnChart(BuyGrid.mSubGrid);   //pass subGrid orders to Dashboard Sub
   
            //---SELL GRID
            //Print(__FUNCTION__,"NUmber of opned sell order is: ", BuyGrid.CountOrder(TYPE,SellGrid.mOrderType,MODE_TRADES));
            SellGrid.ShowGridOrdersOnChart();  //pass main orders to Dashboard Sub
      		SellGrid.ShowGridOrdersOnChart(SellGrid.mSubGrid);   //pass subGrid orders to Dashboard Sub
            }
     }
   }



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


