//+------------------------------------------------------------------+
//|                                        Scalping_Bollinger_EA.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             Author: GitHub Copilot |
//+------------------------------------------------------------------+
#property copyright "GitHub Copilot"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

// Input parameters
input int      InpBandsPeriod = 20;       // Bollinger Bands Period
input int      InpBandsShift  = 0;        // Bollinger Bands Shift
input double   InpBandsDev    = 2.0;      // Bollinger Bands Deviation
input double   InpLotSize     = 0.01;     // Lot size
input int      InpStopLoss    = 100;      // Stop Loss in points
input int      InpTakeProfit  = 100;      // Take Profit in points
input int      InpMagicNum    = 123456;   // Magic Number

// Global variables
CTrade trade;
int bandsHandle;
double upperBand[], lowerBand[], middleBand[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Initialize the trade object
   trade.SetExpertMagicNumber(InpMagicNum);

   // Initialize Bollinger Bands indicator
   bandsHandle = iBands(_Symbol, PERIOD_CURRENT, InpBandsPeriod, InpBandsShift, InpBandsDev, PRICE_CLOSE);
   if(bandsHandle == INVALID_HANDLE)
     {
      Print("Failed to create Bollinger Bands indicator handle");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Release indicator handle
   IndicatorRelease(bandsHandle);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check if we have enough bars
   if(Bars(_Symbol, PERIOD_CURRENT) < InpBandsPeriod)
      return;

   // Copy indicator buffers
   ArraySetAsSeries(upperBand, true);
   ArraySetAsSeries(lowerBand, true);
   ArraySetAsSeries(middleBand, true);

   if(CopyBuffer(bandsHandle, 1, 0, 2, upperBand) < 0 ||
      CopyBuffer(bandsHandle, 2, 0, 2, lowerBand) < 0 ||
      CopyBuffer(bandsHandle, 0, 0, 2, middleBand) < 0)
     {
      Print("Failed to copy indicator buffers");
      return;
     }

   // Get current price
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Check for open positions
   if(PositionsTotal() > 0)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
           {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
              {
               long type = PositionGetInteger(POSITION_TYPE);
               
               // Close Buy if price hits upper band or middle band (optional scalping logic)
               // Here we just rely on TP/SL or a reversal signal
               if(type == POSITION_TYPE_BUY)
                 {
                  if(bid >= upperBand[0]) // Close Buy at Upper Band
                    {
                     trade.PositionClose(ticket);
                    }
                 }
               else if(type == POSITION_TYPE_SELL)
                 {
                  if(ask <= lowerBand[0]) // Close Sell at Lower Band
                    {
                     trade.PositionClose(ticket);
                    }
                 }
              }
           }
        }
     }

   // Entry Logic
   // Buy if price touches lower band (Mean Reversion)
   // Sell if price touches upper band

   // Check if we don't have open positions (Simple one trade at a time)
   bool positionOpen = false;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
        {
         positionOpen = true;
         break;
        }
     }

   if(!positionOpen)
     {
      // Buy Signal: Previous close below lower band, current price moving up? 
      // Or simple touch: Ask <= LowerBand
      if(ask <= lowerBand[0])
        {
         double sl = InpStopLoss > 0 ? ask - InpStopLoss * _Point : 0;
         double tp = InpTakeProfit > 0 ? ask + InpTakeProfit * _Point : 0;
         trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "Bollinger Buy");
        }
      // Sell Signal: Bid >= UpperBand
      else if(bid >= upperBand[0])
        {
         double sl = InpStopLoss > 0 ? bid + InpStopLoss * _Point : 0;
         double tp = InpTakeProfit > 0 ? bid - InpTakeProfit * _Point : 0;
         trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "Bollinger Sell");
        }
     }
  }
