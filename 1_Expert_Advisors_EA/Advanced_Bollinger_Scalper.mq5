//+------------------------------------------------------------------+
//|                                   Advanced_Bollinger_Scalper.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             Author: GitHub Copilot |
//+------------------------------------------------------------------+
#property copyright "GitHub Copilot"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

//--- Inputs
input group "=== Money Management ==="
input double   RiskPercent    = 1.0;      // Risk per trade (%)
input double   FixedLot       = 0.01;     // Fixed Lot (if Risk=0)
input int      StopLoss       = 100;      // Stop Loss (points)
input int      TakeProfit     = 200;      // Take Profit (points)
input int      MagicNumber    = 55555;    // Magic Number

input group "=== Bollinger Bands Settings ==="
input int      BB_Period      = 20;       // Period
input int      BB_Shift       = 0;        // Shift
input double   BB_Deviation   = 2.0;      // Deviation

input group "=== RSI Settings ==="
input int      RSI_Period     = 14;       // RSI Period
input int      RSI_Overbought = 70;       // Overbought Level
input int      RSI_Oversold   = 30;       // Oversold Level

input group "=== Trailing Stop Settings ==="
input bool     UseTrailing    = true;     // Use Trailing Stop
input int      TrailingStop   = 50;       // Trailing Stop (points)
input int      TrailingStep   = 10;       // Trailing Step (points)

input group "=== Time Filter ==="
input bool     UseTimeFilter  = false;    // Use Time Filter
input int      StartHour      = 8;        // Start Hour (0-23)
input int      EndHour        = 20;       // End Hour (0-23)

//--- Global Variables
CTrade trade;
int    handleBB;
int    handleRSI;
double bufUpper[], bufLower[], bufMiddle[];
double bufRSI[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Set Magic Number
   trade.SetExpertMagicNumber(MagicNumber);

   // Initialize Bollinger Bands
   handleBB = iBands(_Symbol, PERIOD_CURRENT, BB_Period, BB_Shift, BB_Deviation, PRICE_CLOSE);
   if(handleBB == INVALID_HANDLE)
     {
      Print("Failed to create Bollinger Bands handle");
      return(INIT_FAILED);
     }

   // Initialize RSI
   handleRSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   if(handleRSI == INVALID_HANDLE)
     {
      Print("Failed to create RSI handle");
      return(INIT_FAILED);
     }

   // Set Array as Series
   ArraySetAsSeries(bufUpper, true);
   ArraySetAsSeries(bufLower, true);
   ArraySetAsSeries(bufMiddle, true);
   ArraySetAsSeries(bufRSI, true);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handleBB);
   IndicatorRelease(handleRSI);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Time Filter
   if(UseTimeFilter)
     {
      MqlDateTime dt;
      TimeCurrent(dt);
      if(dt.hour < StartHour || dt.hour >= EndHour)
         return;
     }

   //--- Manage Open Positions (Trailing Stop)
   ManagePositions();

   //--- Check for New Bar (Optional, but good for scalping stability)
   // For true scalping, we might want every tick, but let's check conditions every tick
   // However, indicators are usually stable on closed bars. 
   // Let's use current price vs bands.

   //--- Get Indicator Data
   if(CopyBuffer(handleBB, 1, 0, 2, bufUpper) < 0 ||
      CopyBuffer(handleBB, 2, 0, 2, bufLower) < 0 ||
      CopyBuffer(handleRSI, 0, 0, 2, bufRSI) < 0)
     {
      return;
     }

   //--- Check for Open Positions
   if(CountPositions() > 0) return; // One trade at a time per symbol

   //--- Trading Logic
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Buy Signal: Price touches Lower Band AND RSI < Oversold
   if(ask <= bufLower[0] && bufRSI[0] < RSI_Oversold)
     {
      double sl = ask - StopLoss * _Point;
      double tp = ask + TakeProfit * _Point;
      double lots = CalculateLotSize(StopLoss * _Point);
      
      trade.Buy(lots, _Symbol, ask, sl, tp, "Adv BB Buy");
     }
   // Sell Signal: Price touches Upper Band AND RSI > Overbought
   else if(bid >= bufUpper[0] && bufRSI[0] > RSI_Overbought)
     {
      double sl = bid + StopLoss * _Point;
      double tp = bid - TakeProfit * _Point;
      double lots = CalculateLotSize(StopLoss * _Point);
      
      trade.Sell(lots, _Symbol, bid, sl, tp, "Adv BB Sell");
     }
  }

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
  {
   if(RiskPercent <= 0) return FixedLot;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;
   
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(tickSize == 0 || tickValue == 0) return FixedLot;

   double moneyPerLotStep = (slDistance / tickSize) * tickValue * lotStep;
   if(moneyPerLotStep == 0) return FixedLot;

   double lots = MathFloor(riskMoney / moneyPerLotStep) * lotStep;

   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(lots < minVol) lots = minVol;
   if(lots > maxVol) lots = maxVol;

   return NormalizeDouble(lots, 2);
  }

//+------------------------------------------------------------------+
//| Count Open Positions for this EA                                 |
//+------------------------------------------------------------------+
int CountPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) > 0)
        {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            count++;
           }
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Manage Trailing Stop                                             |
//+------------------------------------------------------------------+
void ManagePositions()
  {
   if(!UseTrailing) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            double sl = PositionGetDouble(POSITION_SL);
            double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            long type = PositionGetInteger(POSITION_TYPE);

            if(type == POSITION_TYPE_BUY)
              {
               if(currentPrice - priceOpen > TrailingStop * _Point)
                 {
                  double newSL = currentPrice - TrailingStop * _Point;
                  if(newSL > sl + TrailingStep * _Point)
                    {
                     trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
                    }
                 }
              }
            else if(type == POSITION_TYPE_SELL)
              {
               if(priceOpen - currentPrice > TrailingStop * _Point)
                 {
                  double newSL = currentPrice + TrailingStop * _Point;
                  if(sl == 0 || newSL < sl - TrailingStep * _Point)
                    {
                     trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
                    }
                 }
              }
           }
        }
     }
  }
