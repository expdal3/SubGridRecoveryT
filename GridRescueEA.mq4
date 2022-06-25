//+------------------------------------------------------------------+
//|                                            SubGridRecoveryEA.mq4 |
//|                                       Copyright 2022, BlueStone. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright           "Copyright 2022, BlueStone."
#property link                "https://www.mql5.com"
#property version             "1.08"
#property description         "EA to rescue Grid / Martingale Drawdown by closing off sub-grid orders"
#property strict


#include "include/GridTradeFunction.mqh"
#include "include/GridOrderManagement.mqh"
#include "include/LogsFunction.mqh"
#include <Blues/TradeInfoClass.mqh>
#include <Blues/Credentials.mqh>


extern bool                                     InpOpenNewGridTrade   = false; // Open test grid trade?


extern  string  __0__                                                   = "_______ DD Rescue Settings __________";
extern int                                      InpMagicNumber    =  1111;          //Magic number
extern string                                   InpTradeComment   = __FILE__;       //Trade comment
extern  int                                     InpLevelToStartRescue   = 4; // Order To Start DD Reduce
extern  int                                     InpSubGridProfitToClose = 1; // Sub-grid's Profit to close 
extern  bool                                    InpShowPanel = false;        // Show panel

extern  string  __1__                                                   = "_______ Advance Rescue Settings __________";
extern  ENUM_BLUES_SUBGRID_MODE_SCHEME          InpRescueScheme         = _default_;   // Rescue Scheme


CTradeInfo *tradeInfo;
CGridMaster *BuyGrid;
CGridMaster *SellGrid;
//---declare dashboard logggings
CDashboard BuyDashboardMaster("BuyMasterGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 750                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 
   
CDashboard BuyDashboardSub("BuySubGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 3                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 

CDashboard SellDashboardMaster("SellMasterGridDB"
	                              , CORNER_RIGHT_LOWER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 750                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 
   
CDashboard SellDashboardSub("SellSubGridDB"
	                              , CORNER_RIGHT_LOWER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 3                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 


string MasterGridHeaderTxt = "Master Grid orders                                           " ;
string SubGridHeaderTxt = "Sub Grid orders                                             ";
string ColHeaderTxt =   "Ticket   Symbol   Type   LotSize   OpenPrice   Profit           "  ;
int TotalRowsSize = 10;
int HeaderRowsToSkip = 3;

//---input for file saving
string                                          inpBuyFileName        = __FILE__ + "BuyGrid";
string                                          inpSellFileName       = __FILE__ + "SellGrid";

/*
//---Loggings
#include		<Orchard\Dialog\Dashboard.mqh>
CDashboard	*Dashboard;
string GridHeaderTxt = "Master Grid orders                                  " ;
string ColHeaderTxt =   "Ticket   Symbol   Type   LotSize   OpenPrice   Profit "  ;

int DashboardRowsToSkip=3;
*/

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//internal parameters
int historyTotal = OrdersHistoryTotal();
int openTotal = OrdersTotal();
double AcctBalance,   AcctEquity;
int gridSize;
int _OrdersTotal = 0;

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
   //--- Declare grid objects
   BuyGrid = new CGridMaster(OP_BUY,InpLevelToStartRescue,InpRescueScheme,InpMagicNumber,InpTradeComment);                 // init new Grid objects with the InpMagicNumber
   SellGrid = new CGridMaster(OP_SELL,InpLevelToStartRescue,InpRescueScheme,InpMagicNumber,InpTradeComment);                 // init new Grid objects with the InpMagicNumber
   //Print("Current order type is:", OrderTypeName (Grid.mOrderType));
   //tiebreak=false;
   //bool OrderOpenedChange=false;

   //--- Loggings Init - Create 2 dashboard
   if(InpShowPanel==true)
   {
   if(InpTradeMode==Buy_and_Sell || InpTradeMode==BuyOnly){   
      AddGridDashboard(BuyDashboardMaster, "BuyMasterGridDB", MasterGridHeaderTxt, ColHeaderTxt);
      AddGridDashboard(BuyDashboardSub, "BuySubGridDB", SubGridHeaderTxt, ColHeaderTxt);
      }
   
   if(InpTradeMode==Buy_and_Sell || InpTradeMode==SellOnly){
      AddGridDashboard(SellDashboardMaster, "SellMasterGridDB", MasterGridHeaderTxt, ColHeaderTxt);
      AddGridDashboard(SellDashboardSub, "SellSubGridDB", SubGridHeaderTxt, ColHeaderTxt);
   }
   }else{
   BuyDashboardMaster.DeleteAll();
   SellDashboardMaster.DeleteAll();
   BuyDashboardSub.DeleteAll();
   SellDashboardSub.DeleteAll();
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
   STradeSum BuySum;
   STradeSum SellSum;
   // Start martingale trades
   if(InpOpenNewGridTrade)
     {

         GetSum(BuySum,OP_BUY, InpMagicNumber);
         GetSum(SellSum,OP_SELL, InpMagicNumber);
   
   if(IsTradeAllowed() && !IsTradeContextBusy() && IsTesting())         //Only allow open new test trading order if in demo account 
      {
      switch(InpTradeMode)
        {
         case  Buy_and_Sell:
            OpenGridTrades(BuySum,OP_BUY, InpMagicNumber, InpTradeComment); 
            OpenGridTrades(SellSum,OP_SELL, InpMagicNumber, InpTradeComment); 
           break;
         case  BuyOnly:
            OpenGridTrades(BuySum,OP_BUY, InpMagicNumber, InpTradeComment); 
           break;
         case  SellOnly:
            OpenGridTrades(SellSum,OP_SELL, InpMagicNumber, InpTradeComment); 
           break;
         default:
           break;
        }
      
      }   
     }
     
   //Get the latest order info
   if(_OrdersTotal!=OrdersTotal())
     {
      _OrdersTotal = OrdersTotal();
      BuyGrid.GetOrdersOpened();           //pass data to Grid array that match magicnumber BuyGrid.mOrders
      SellGrid.GetOrdersOpened();           //pass data to Grid array that match magicnumber SellGrid.mOrders
     }

   BuyGrid.GetSubGridOrders();
   BuyGrid.GetGridStats();


   SellGrid.GetSubGridOrders();
   SellGrid.GetGridStats();

      
   //Collect data to array
   if(IsNewBar() )
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
     }}
   if(BuyGrid.mIsRecovering==true)BuyGrid.CloseSubGrid(BuyGrid.mSubGrid, InpSubGridProfitToClose);
   if(SellGrid.mIsRecovering==true)SellGrid.CloseSubGrid(SellGrid.mSubGrid, InpSubGridProfitToClose);

  }


//+------------------------------------------------------------------+


void AddGridDashboard(CDashboard &dashboard
                     , string dashboardObjName
                     , string tableheadertxt
                     , string colheadertxt
                     , int rows = 10
                     , int corner = CORNER_RIGHT_UPPER
                     , int xdist = 400
                     , int ydist =  15
                     , color txtclr =  clrWhite
                     , string txtfont  =  "Verdana"
                     , int txtsize  =  10
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
  int    lastgridsize;                  //hold the last gridsize when the file was saved
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

     if(IsTesting()){
     Print("EA is in Testing mode: ", (bool)IsTesting());
     Print("src file ",terminal_data_path+"\\tester\\files\\"+filename);
     Print("dst file ",terminal_data_path+"\\MQL4\\Files\\"+filename);
     string src_file_path = terminal_data_path+"\\tester\\files\\"+filename;
     string dst_file_path = terminal_data_path+"\\MQL4\\Files\\"+filename;
     if(!FileCopy(src_file_path,0,dst_file_path,FILE_REWRITE))PrintFormat("File copy failed! Error code=%d",GetLastError());
     }
     
}


