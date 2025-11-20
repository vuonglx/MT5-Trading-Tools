//+------------------------------------------------------------------+
//|                                                  vIndicator.mq5    |
//|                        Copyright 2025, Vuong Le                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Vuong Le "
#property link      "https://www.moviot.com"
#property version   "1.08"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- input parameters
input int    FontSize = 10;               // Font Size (Timer)
input color  FontColor = clrWhite;        // Font Color (Timer)
input int    VerticalOffset = 20;         // Vertical Offset (Timer, points)
input ENUM_BASE_CORNER Corner = CORNER_RIGHT_UPPER; // Chart Corner (Timer)
input color  BreakEvenColor = clrYellow;  // Break Even Line Color
input ENUM_LINE_STYLE BreakEvenStyle = STYLE_DASH; // Break Even Line Style
input int    BreakEvenWidth = 1;          // Break Even Line Width
input int    InfoFontSize = 12;           // Diff Lots & BE Font Size
input color  InfoFontColor = clrYellow;   // Diff Lots & BE Font Color
input int    InfoVerticalOffset = 10;     // Diff Lots & BE Vertical Offset (points)
input long   FilterMagicNumber = -1;      // Magic Number Filter (-1 for all)
input string FilterComment = "";          // Comment Filter (empty for all)

//--- global variables
datetime lastBarTime;
string timerName = "CandleTimer";
string breakEvenLineName = "BreakEvenLine";
string infoLabelName = "InfoLabel";
ulong lastTicket;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
   // Remove any existing objects
   ObjectDelete(0, timerName);
   ObjectDelete(0, breakEvenLineName);
   ObjectDelete(0, infoLabelName);
   lastBarTime = 0;
   lastTicket = 0;
   EventSetTimer(1); // Update every second
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, timerName);
   ObjectDelete(0, breakEvenLineName);
   ObjectDelete(0, infoLabelName);
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Get current bar's open time
   datetime currentBarTime = time[rates_total - 1];
   
   // Check if new bar has started
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
   }
   
   // Update timer and break-even info
   UpdateTimer(rates_total, time, high);
   UpdateBreakEvenAndInfo(time[rates_total - 1]);
   
   ChartRedraw();
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Update the timer display                                          |
//+------------------------------------------------------------------+
void UpdateTimer(const int rates_total, const datetime &time[], const double &high[])
{
   // Get timeframe in seconds
   int periodSeconds = PeriodSeconds();
   if(periodSeconds == 0) return;
   
   // Calculate time remaining until next candle
   datetime currentTime = TimeCurrent();
   if(currentTime == 0) return; // Prevent invalid time
   datetime nextBarTime = time[rates_total - 1] + periodSeconds;
   int secondsLeft = (int)(nextBarTime - currentTime);
   
   if(secondsLeft < 0) return; // Prevent negative display
   
   // Format time as MM:SS
   int minutes = secondsLeft / 60;
   int seconds = secondsLeft % 60;
   string timeText = StringFormat("%02d:%02d", minutes, seconds);
   
   // Get price coordinate (high of current candle + offset)
   double price = high[rates_total - 1] + VerticalOffset * Point();
   
   // Create or update text object
   if(!ObjectCreate(0, timerName, OBJ_TEXT, 0, time[rates_total - 1], price))
   {
      ObjectMove(0, timerName, 0, time[rates_total - 1], price);
   }
   
   ObjectSetString(0, timerName, OBJPROP_TEXT, timeText);
   ObjectSetInteger(0, timerName, OBJPROP_COLOR, FontColor);
   ObjectSetInteger(0, timerName, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, timerName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, timerName, OBJPROP_CORNER, Corner);
   ObjectSetInteger(0, timerName, OBJPROP_ANCHOR, ANCHOR_CENTER);
}

//+------------------------------------------------------------------+
//| Update the break-even line and info label (diff lots, BE, profit) |
//+------------------------------------------------------------------+
void UpdateBreakEvenAndInfo(datetime currentTime)
{
   // Calculate break-even price, differential lots, and profit/loss
   double buyVolume = 0.0, sellVolume = 0.0;
   double weightedPrice = 0.0;
   double totalProfit = 0.0;
   int totalOrders = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            long magic = PositionGetInteger(POSITION_MAGIC);
            string comment = PositionGetString(POSITION_COMMENT);
            
            // Apply magic number and comment filters
            if((FilterMagicNumber == -1 || magic == FilterMagicNumber) &&
               (FilterComment == "" || comment == FilterComment))
            {
               double price = PositionGetDouble(POSITION_PRICE_OPEN);
               double volume = PositionGetDouble(POSITION_VOLUME);
               double profit = PositionGetDouble(POSITION_PROFIT);
               double swap = PositionGetDouble(POSITION_SWAP);
               int posType = (int)PositionGetInteger(POSITION_TYPE);
               
               weightedPrice += price * volume;
               totalProfit += profit + swap; // Net P/L (profit + swap)
               if(posType == POSITION_TYPE_BUY)
                  buyVolume += volume;
               else if(posType == POSITION_TYPE_SELL)
                  sellVolume += volume;
               totalOrders++;
            }
         }
      }
   }
   
   // Update last ticket to track position changes
   lastTicket = GetLastOrderTicket();
   
   // Calculate differential lots
   double diffVolume = buyVolume - sellVolume;
   
   // Debug output to verify data
   Print("Total Orders: ", totalOrders, " | Buy Volume: ", buyVolume, " | Sell Volume: ", sellVolume);
   
   // Update or remove break-even line and info label
   if(totalOrders > 0 && (buyVolume > 0 || sellVolume > 0))
   {
      double totalVolume = buyVolume + sellVolume;
      if(totalVolume == 0) return; // Prevent division by zero
      double breakEvenPrice = weightedPrice / totalVolume;
      
      // Create or update horizontal line
      if(!ObjectCreate(0, breakEvenLineName, OBJ_HLINE, 0, 0, breakEvenPrice))
      {
         ObjectSetDouble(0, breakEvenLineName, OBJPROP_PRICE, breakEvenPrice);
      }
      
      ObjectSetInteger(0, breakEvenLineName, OBJPROP_COLOR, BreakEvenColor);
      ObjectSetInteger(0, breakEvenLineName, OBJPROP_STYLE, BreakEvenStyle);
      ObjectSetInteger(0, breakEvenLineName, OBJPROP_WIDTH, BreakEvenWidth);
      ObjectSetInteger(0, breakEvenLineName, OBJPROP_BACK, false);
      ObjectSetString(0, breakEvenLineName, OBJPROP_TEXT, "Break Even");
      
      // Create or update info label (differential lots, break-even price, profit/loss)
      string infoText = StringFormat("Diff Lots: %.2f | BE: %.*f | P/L: %.2f",
                                    diffVolume, (int)_Digits, breakEvenPrice, totalProfit);
      double labelPrice = breakEvenPrice + InfoVerticalOffset * Point();
      
      // Get the chart's time range to center the text
      datetime chartStartTime = iTime(_Symbol, Period(), 0); // Start of visible chart
      datetime chartEndTime = TimeCurrent();
      if(chartEndTime < chartStartTime) chartEndTime = iTime(_Symbol, Period(), 0) + PeriodSeconds() * 100; // Fallback
      datetime centerTime = chartStartTime + (chartEndTime - chartStartTime) / 2;
      
      // Debug output for positioning
      Print("Center Time: ", TimeToString(centerTime), " | Label Price: ", DoubleToString(labelPrice, _Digits));
      
      if(!ObjectCreate(0, infoLabelName, OBJ_TEXT, 0, centerTime, labelPrice))
      {
         ObjectMove(0, infoLabelName, 0, centerTime, labelPrice);
      }
      
      ObjectSetString(0, infoLabelName, OBJPROP_TEXT, infoText);
      ObjectSetInteger(0, infoLabelName, OBJPROP_COLOR, InfoFontColor);
      ObjectSetInteger(0, infoLabelName, OBJPROP_FONTSIZE, InfoFontSize);
      ObjectSetString(0, infoLabelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, infoLabelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, infoLabelName, OBJPROP_BACK, false);
   }
   else
   {
      ObjectDelete(0, breakEvenLineName);
      ObjectDelete(0, infoLabelName);
      Print("No valid positions found for symbol: ", _Symbol);
   }
}

//+------------------------------------------------------------------+
//| Get the last order ticket to detect changes                       |
//+------------------------------------------------------------------+
ulong GetLastOrderTicket()
{
   ulong ticket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong currentTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(currentTicket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            long magic = PositionGetInteger(POSITION_MAGIC);
            string comment = PositionGetString(POSITION_COMMENT);
            
            // Apply magic number and comment filters
            if((FilterMagicNumber == -1 || magic == FilterMagicNumber) &&
               (FilterComment == "" || comment == FilterComment))
            {
               ticket = MathMax(ticket, currentTicket);
            }
         }
      }
   }
   return ticket;
}

//+------------------------------------------------------------------+
//| Timer event handler                                               |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Force update on timer event
   ChartRedraw();
}

//+------------------------------------------------------------------+
