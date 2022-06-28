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
extern string                           InpSymbol                          = "";              //Symbol(s) - separated by comma (,)
extern string                           InpSymbolSuffix                    = "";             //Broker's symbol suffix
extern string                           InpMagicNumber                     =  1111;          //EA Magic number(s) - separated by comma (,)
extern string                           InpTradeComment                    = __FILE__;       //EA Trade comment to rescue
extern  int                             InpLevelToStartRescue              = 4;              // Order To Start Rescue
extern  double                          InpSubGridProfitToClose            = 1;              // Sub-grid's Profit to close 
extern  bool                            InpShowPanel                       = false;               // Show master and sub grid panel
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
//---inputs for dashboard logggings when OneChartSetUp=false (OnePair)
CDashboard BuyDashboardMaster("BuyMasterGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 400                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 
   
CDashboard BuyDashboardSub("BuySubGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 3                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 

CDashboard SellDashboardMaster("SellMasterGridDB"
	                              , CORNER_RIGHT_LOWER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 400                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 
   
CDashboard SellDashboardSub("SellSubGridDB"
	                              , CORNER_RIGHT_LOWER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 3                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 

string                                       MasterGridHeaderTxt     = "Master Grid orders                                " ;
string                                       SubGridHeaderTxt        = "Sub Grid orders                                   ";
string                                       ColHeaderTxt            = "Ticket   Symbol   Type   LotSize   OpenPrice   Profit   "  ;
int                                          TotalRowsSize           = 15;
int                                          HeaderRowsToSkip        = 3;

//---inputs for dashboard logggings when OneChartSetUp=true (MultiPair)
CDashboard MultiPairDashboardMaster("MultiPairGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 400                         // X Distance from margin
	                              , 15); 
string                                       MultiPairDBHeaderTxt     = "Master Grid orders                                " ;
string                                       ColHeaderTxt            = "GridName   Type   Profit   GridSize   BeingRescued?   Iteration   RescuedCount   "  ;
int                                          TotalRowsSize           = 15;
int                                          HeaderRowsToSkip        = 3;



//---input for file saving
string                                       inpBuyFileName          = __FILE__ + "BuyGrid";
string                                       inpSellFileName         = __FILE__ + "SellGrid";

//---other internal parameters
double AcctBalance,   AcctEquity;
int _OrdersTotal = 0;
int _magicnumber;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- 

   if(inpUnlockPass!=pass)
     {
      if (MessageBox("Please enter pass to continue","Password needed!",MB_OK)==1);
      ExpertRemove();

   } else{
      AcctBalance=AccountBalance();
      AcctEquity = AccountEquity();
      tradeInfo = new CTradeInfo();
   
      if(IsOneChartSetup()==true){
         BuyGridCollection = new CGridCollection(InpSymbol,InpSymbolSuffix,InpMagicNumber,OP_BUY,InpLevelToStartRescue,InpRescueScheme, InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment);
         SellGridCollection = new CGridCollection(InpSymbol,InpSymbolSuffix,InpMagicNumber,OP_SELL,InpLevelToStartRescue,InpRescueScheme, InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment);
         Print(__FUNCTION__,"IsOneChartSetup = ", IsOneChartSetup());
         
         //--- Loggings Init - Create 2 dashboard
      
      }else{
   //--- Declare grid objects
         StringReplace(InpMagicNumber,",","");                                                   //make sure no trailing ","
         _magicnumber = StringToInteger(StringTrimRight(StringTrimLeft(InpMagicNumber)));        //make sure no trailing blank space
         BuyGrid = new CGridMaster(Symbol(),_magicnumber,OP_BUY,InpLevelToStartRescue,InpRescueScheme,InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment);                 // init new Grid objects with the InpMagicNumber
         SellGrid = new CGridMaster(Symbol(),_magicnumber,OP_SELL,InpLevelToStartRescue,InpRescueScheme,InpSubGridProfitToClose,InpIterationModeAndProfitToCloseStr,InpTradeComment);                 // init new Grid objects with the InpMagicNumber
         Print(__FUNCTION__,"IsOneChartSetup = ", IsOneChartSetup());
   
         //--- Loggings Init - Create 2 dashboard
      #ifndef	PRODMODE                         // #if in test mode
         if(InpShowPanel==true)
         {
         if(InpTradeMode==Buy_and_Sell || InpTradeMode==BuyOnly){   
            AddGridDashboardOnePair(BuyDashboardMaster, "BuyMasterGridDB", "BUY "+MasterGridHeaderTxt, ColHeaderTxt, InpPanelFontSize);
            AddGridDashboardOnePair(BuyDashboardSub, "BuySubGridDB", "BUY "+SubGridHeaderTxt, ColHeaderTxt, InpPanelFontSize);
            }
         
         if(InpTradeMode==Buy_and_Sell || InpTradeMode==SellOnly){
            AddGridDashboardOnePair(SellDashboardMaster, "SellMasterGridDB", "SELL "+ MasterGridHeaderTxt, ColHeaderTxt, InpPanelFontSize);
            AddGridDashboardOnePair(SellDashboardSub, "SellSubGridDB", "SELL "+SubGridHeaderTxt, ColHeaderTxt, InpPanelFontSize);
            }
         }else{
         BuyDashboardMaster.DeleteAll();
         SellDashboardMaster.DeleteAll();
         BuyDashboardSub.DeleteAll();
         SellDashboardSub.DeleteAll();
         }
      #else                                     // #if not in test mode
         if(InpShowPanel==true)
            {
            AddGridDashboardOnePair(BuyDashboardMaster, "BuyMasterGridDB", MasterGridHeaderTxt, ColHeaderTxt,TotalRowsSize);
            AddGridDashboardOnePair(BuyDashboardSub, "BuySubGridDB", SubGridHeaderTxt, ColHeaderTxt,TotalRowsSize);
            AddGridDashboardOnePair(SellDashboardMaster, "SellMasterGridDB", MasterGridHeaderTxt, ColHeaderTxt,TotalRowsSize);
            AddGridDashboardOnePair(SellDashboardSub, "SellSubGridDB", SubGridHeaderTxt, ColHeaderTxt,TotalRowsSize);
         }else{
            BuyDashboardMaster.DeleteAll();
            SellDashboardMaster.DeleteAll();
            BuyDashboardSub.DeleteAll();
            SellDashboardSub.DeleteAll();
         }
      #endif
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
      )
      SaveData(BuyGrid,inpBuyFileName);
      SaveData(SellGrid,inpSellFileName);
      
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
         BuyGridCollection.RescueGrid();
         SellGridCollection.RescueGrid();
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
   //Collect data to array
   if(IsNewBar() )
     {
     if(IsOneChartSetup()==false)
       {
         //---BUY GRID
         //Print(__FUNCTION__,"NUmber of opned buy order is: ", BuyGrid.CountOrder(TYPE,BuyGrid.mOrderType,MODE_TRADES));
         if(InpShowPanel==true)
           {
            //Print("BuyGrid ArraySize is ", ArraySize(BuyGrid.mOrders) );
            BuyGrid.ShowGridOrdersOnChart(BuyDashboardMaster, 4);  //pass main orders to Dashboard Sub
   		   BuyGrid.ShowGridOrdersOnChart(BuyDashboardSub, BuyGrid.mSubGrid, 3);   //pass subGrid orders to Dashboard Sub
           }
   
        //---SELL GRID
         //Print(__FUNCTION__,"NUmber of opned sell order is: ", BuyGrid.CountOrder(TYPE,SellGrid.mOrderType,MODE_TRADES));
         if(InpShowPanel==true)
           {
            SellGrid.ShowGridOrdersOnChart(SellDashboardMaster, 4);  //pass main orders to Dashboard Sub
      		SellGrid.ShowGridOrdersOnChart(SellDashboardSub, SellGrid.mSubGrid, 3);   //pass subGrid orders to Dashboard Sub
            }
       }
     }
   }



  }


//+------------------------------------------------------------------+

bool IsOneChartSetup(){
   bool isonechart = false;
   string symbolarr[];
   string magicarr[];
   if(StringSplitToArray(symbolarr,InpSymbol,",")>1
      || StringSplitToArray(magicarr,InpMagicNumber,",")>1
      )
   isonechart= true;
   else isonechart = false;
  
  return (isonechart);             
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


