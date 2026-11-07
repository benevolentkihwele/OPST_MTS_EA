
#property copyright "OPST MTS EA"
#property version   "1.00"
#property description "Automated OPST + MTS*1 Trading Strategy"

#include "Modules/CandleDetection.mqh"
#include "Modules/OPSTValidation.mqh"
#include "Modules/MTSConfirmation.mqh"
#include "Modules/RetestDetection.mqh"
#include "Modules/RiskManagement.mqh"
#include "Modules/TradeExecution.mqh"

//+------------------------------------------------------------------+
//| Main EA Settings                                                 |
//+------------------------------------------------------------------+

input ENUM_TIMEFRAMES TradingTimeframe = PERIOD_M15;
input int MaximumSpreadPoints = 50;
input int RLookbackCandles = 100;

input bool EnableBuy = true;
input bool EnableSell = true;

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+

MTSData activeMTS;

bool setupActive = false;

datetime lastProcessedBar = 0;

//+------------------------------------------------------------------+
//| Initialize EA                                                    |
//+------------------------------------------------------------------+

int OnInit()
{
   InitializeTradeEngine();

   activeMTS.state = MTS_WAITING;
   activeMTS.trade_executed = false;

   Print("OPST MTS EA initialized.");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(TradingTimeframe));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Check spread                                                     |
//+------------------------------------------------------------------+

bool IsSpreadAcceptable()
{
   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
      return false;

   double spread =
      (tick.ask - tick.bid) / _Point;

   return spread <= MaximumSpreadPoints;
}

//+------------------------------------------------------------------+
//| Find latest R candle                                             |
//+------------------------------------------------------------------+

bool FindRAndOPSTSetup(OPSTSetup &setup)
{
   for(int shift = 3;
       shift < RLookbackCandles;
       shift++)
   {
      CandleData r;
      CandleData first;
      CandleData second;

      if(!GetCandleData(
         _Symbol,
         TradingTimeframe,
         shift,
         r))
         continue;

      if(!GetCandleData(
         _Symbol,
         TradingTimeframe,
         shift - 1,
         first))
         continue;

      if(!GetCandleData(
         _Symbol,
         TradingTimeframe,
         shift - 2,
         second))
         continue;

      if(!IsValidCandle(r) ||
         !IsValidCandle(first) ||
         !IsValidCandle(second))
         continue;

      if(EnableBuy &&
         BuildOPSTSetup(
            r,
            first,
            second,
            OPST_BUY,
            setup))
         return true;

      if(EnableSell &&
         BuildOPSTSetup(
            r,
            first,
            second,
            OPST_SELL,
            setup))
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Detect a new M15 candle                                          |
//+------------------------------------------------------------------+

bool IsNewBar()
{
   datetime currentBar = iTime(
      _Symbol,
      TradingTimeframe,
      0
   );

   if(currentBar == 0)
      return false;

   if(currentBar != lastProcessedBar)
   {
      lastProcessedBar = currentBar;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Main tick                                                        |
//+------------------------------------------------------------------+

void OnTick()
{
   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
      return;

   // Manage an existing confirmed setup on every tick.
   if(setupActive)
   {
      if(CheckMTSInvalidation(
         tick.bid,
         tick.ask,
         activeMTS))
      {
         Print("MTS setup invalidated.");
         setupActive = false;
         return;
      }

      if(!IsSpreadAcceptable())
         return;

      if(DetectMTSRetest(
         activeMTS,
         tick.bid,
         tick.ask))
      {
         if(ExecuteOPSTTrade(activeMTS))
         {
            Print("OPST setup consumed.");
            setupActive = false;
         }
      }

      return;
   }

   // Find completed candle patterns only on a new bar.
   if(!IsNewBar())
      return;

   OPSTSetup setup;

   if(!FindRAndOPSTSetup(setup))
      return;

   InitializeMTS(setup, activeMTS);

   if(ConfirmMTS(setup, activeMTS))
   {
      setupActive = true;

      Print(
         "MTS*1 CONFIRMED. Level: ",
         activeMTS.level
      );
   }
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
{
   Print("OPST MTS EA stopped.");
}
