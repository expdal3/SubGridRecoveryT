//+------------------------------------------------------------------+
//|                                            SubGridRecoveryEA.mq4 |
//|                                       Copyright 2022, BlueStone. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, BlueStone."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict


#include "include/GridTradeFunction.mqh"
#include "include/GridOrderManagement.mqh"
#include "include/LogsFunction.mqh"
#include <Arrays/ArrayInt.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Blues/TradeInfoClass.mqh>

extern  int OrderToStartDDReduce =  7  ; // Order To Start DD Reduce

CTradeInfo *tradeInfo;
CGridMaster *Grid;

//---declare dashboard logggings
CDashboard DashboardMaster("MasterGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 500                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 
   
CDashboard DashboardSub("SubGridDB"
	                              , CORNER_RIGHT_UPPER         // Corner (0=top left 1=topright 2=bottom left 3=bottom right)
	                              , 3                         // X Distance from margin
	                              , 15);                      // Y Distance from margin 

string MasterGridHeaderTxt = "Master Grid orders                                  " ;
string SubGridHeaderTxt = "Sub Grid orders                                  ";
string ColHeaderTxt =   "Ticket   Symbol   Type   LotSize   OpenPrice   Profit "  ;
int TotalRowsSize = 10;
int HeaderRowsToSkip = 3;



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
   AcctBalance=AccountBalance();
   AcctEquity = AccountEquity();
   tradeInfo = new CTradeInfo();
   //--- Declare grid objects
   Grid = new CGridMaster();                 // new Grid objects
   tiebreak=false;
   bool OrderOpenedChange=false;

   //--- Loggings Init - Create 2 dashboard
   AddGridDashboard(DashboardMaster, "MasterGridDB", MasterGridHeaderTxt, ColHeaderTxt);
   AddGridDashboard(DashboardSub, "SubGridDB", SubGridHeaderTxt, ColHeaderTxt);
   //--

   
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
      SaveData(Grid);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   // Start martingale trades
   STradeSum sum;
   GetSum(sum);
   if(IsTradeAllowed() && !IsTradeContextBusy()) OpenGridTrades(sum);   
   
   //Collect data to array
   if(IsNewBar() )
     {
      Grid.GetOrdersOpened(Grid.mOrders,InpMagicNumber);           //pass data to Grid array that match magicnumber
      Grid.GetSubGridOrders(Grid.mSubGrid,Grid.mSize,OrderToStartDDReduce);
     }

   static datetime	currentTime;
	if (currentTime!=Time[0]) {
		Grid.ShowGridOrdersOnChart(DashboardSub, Grid.mSubGrid, 3);   //pass subGrid orders to Dashboard Sub
      
      Grid.ShowGridOrdersOnChart(DashboardMaster, Grid.mOrders, 3);  //pass main orders to Dashboard Sub
 
		currentTime	=	Time[0];
	}  
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
	dashboard.AddRow("", txtclr, txtfont, txtsize-2);
	dashboard.AddRow(colheadertxt, txtclr, txtfont, txtsize-2);
	
   //--- Add 10+ blank row to get the space for the list
	for(int i=0;i<rows-1;i++)
	  {
	   dashboard.AddRow("", txtclr, txtfont, txtsize-2);
	  }
}
void SaveData(CGridMaster &grid){
   grid.ConvertToBinFormat();  // grid.mOrders, grid.mBinOrders transfer orders to Bin-writable format (remove all string variable)
   string terminal_data_path = TerminalInfoString(TERMINAL_DATA_PATH);
   //string filename = terminal_data_path + "\\MQL4\\Files\\SubGridRecoveryFiles\\"+"mastegridorders.bin";
   string filename = "mastegridorders.bin";
   filename = StringTrimRight(StringTrimLeft(filename));
   PrintFormat("the file name is %s", filename);               //"C:/Users/ducan/AppData/Roaming/MetaQuotes/Terminal/17B5FF217FE004B792EFA9D824B75EEC/MQL4/Files/SubGridRecoveryFiles/mastegridorders.bin";

   int filehandle = FileOpen(filename,FILE_WRITE|FILE_BIN);

   if(filehandle!=INVALID_HANDLE)
     {
      Print("File is valid");
      //--- prepare the counter of the number of bytes
      uint counter=0;
      FileWrite(filehandle,__FILE__);
      FileWrite(filehandle,TimeCurrent());
      FileWrite(filehandle,grid.mSize);

           
      for(int i=0;i<grid.mSize-1;i++)
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
     Print("Is tsting ", IsTesting());
     Print("src file ",terminal_data_path+"\\tester\\files\\"+filename);
     Print("dst file ",terminal_data_path+"\\MQL4\\Files\\SubGridRecoveryFiles\\"+filename);
     string src_file_path = terminal_data_path+"\\tester\\files\\"+filename;
     string dst_file_path = terminal_data_path+"\\MQL4\\Files\\SubGridRecoveryFiles\\"+filename;
     if(IsTesting()){
     if(!FileCopy(src_file_path,0,dst_file_path,FILE_REWRITE))PrintFormat("Error read data. Error code=%d",GetLastError());
     }
     
}

