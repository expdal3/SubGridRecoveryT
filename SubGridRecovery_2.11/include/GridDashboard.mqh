//---Loggings
#include		<Orchard\Dialog\Dashboard.mqh>

#define  ONEPAIR     1
#define  MULTIPAIR   2


class CGridDashboard //: public CDashboard
  {
  
public:      
      CDashboard     *mDashboard;
      string         mName;
      int            mCorner;
      int            mXDistance;
      int            mYDistance;
      
      string         mTableHeaderTxt;
      string         mColHeaderTxt;
      int            mTotalRows;
      int            mHeaderRowsToSkip;
public:
                     //CGridDashboard: public CDashboard(void);
                     CGridDashboard(string name,int corner,int xDistance, int yDistance, int rows, int headerrowstoskip)
                                    :mName(name),mCorner(corner),mXDistance(xDistance),mYDistance(yDistance), mTotalRows(rows),mHeaderRowsToSkip(headerrowstoskip){
                                     mDashboard = new CDashboard(mName,mCorner,mXDistance,mYDistance);
                                    };
                                       //    {Init("TableText"
                                       //      ,"ColumnHeaderText"
                                       //      ,10
                                       //      ,"Arial"
                                       //      ,clrWhite
                                       //      );}
                                             
                     //CGridDashboard(string name,int corner,int xDistance, int yDistance):public CDashboard(name,corner,xDistance,yDistance);
                    ~CGridDashboard(void);
                    
      int            Add(string tableheadertxt
                         , string colheadertxt
                         , int txtsize
                         , string txtfont="Arial"
                         , color txtcolor=clrWhite);     //string tableheadertxt,string colheadertxt,int rows,int headerrowstoskip
                   
      //int            Create(int type, string name, string tableheadertxt, string colheadertxt, int rows, int corner, int xdist, int ydist, int txtsize, string txtfont, color txtcolor);               
  };
  
int CGridDashboard::Add(string tableheadertxt
                         , string colheadertxt
                         , int txtsize
                         , string txtfont="Arial"
                         , color txtcolor=clrWhite
                         )
{
   mTableHeaderTxt   =    tableheadertxt;
   mColHeaderTxt     =    colheadertxt;
   
   mDashboard.AddRow(tableheadertxt, txtcolor, txtfont, txtsize);
	for(int i=0;i<mHeaderRowsToSkip-2;i++)
	  {
	   	mDashboard.AddRow("", txtcolor, txtfont, txtsize-2);        // blank rows for display additional stats
	  }
	mDashboard.AddRow(colheadertxt, txtcolor, txtfont, txtsize-2);
	
   //--- Add n+ blank row to get the space for the list
	for(int i=0;i<mTotalRows-1;i++)
	  {
	   mDashboard.AddRow("", txtcolor, txtfont, txtsize-2);
	  }
   
   return(INIT_SUCCEEDED);
   
}
