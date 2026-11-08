
#property copyright "OPST MTS EA"
#property version   "2.00"
#property description "Automated OPST Module 1 and Module 2 Trading System"

#include "Modules/TradeExecution.mqh"
#include "Modules/RetestDetection.mqh"

//==============================================================
// STRATEGY SETTINGS
//==============================================================

input group "OPST Strategy"

input ENUM_OPST_STRATEGY SelectedStrategy = STRATEGY_MODULE_1;

input ENUM_TIMEFRAMES TradingTimeframe = PERIOD_M15;

input int RLookbackCandles = 100;

input bool EnableBuy = true;
input bool EnableSell = true;

input group "Market Filters"

input int MaximumSpreadPoints = 50;

//==============================================================
// GLOBAL STATE
//==============================================================

MTSData activeMTS;

bool setupActive = false;

datetime lastProcessedBar = 0;
datetime lastUsedSetupTime = 0;

double previousBid = 0.0;
double previousAsk = 0.0;

//==============================================================
// INITIALIZATION
//==============================================================

int OnInit()
{
   InitializeTradeEngine();

   activeMTS.state = MTS_WAITING;
   activeMTS.trade_executed = false;

   lastProcessedBar = iTime(
      _Symbol,
      TradingTimeframe,
      0
   );

   Print("--------------------------------");
   Print("OPST MTS EA V2.00 INITIALIZED");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(TradingTimeframe));
   Print("Strategy: ", EnumToString(SelectedStrategy));
   Print("Risk: ", RiskPercent, "%");
   Print("Reward: 1:", RiskRewardRatio);
   Print("--------------------------------");

   return INIT_SUCCEEDED;
}

//==============================================================
// NEW BAR DETECTION
//==============================================================

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

//==============================================================
// SPREAD VALIDATION
//==============================================================

bool IsSpreadAcceptable()
{
   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
      return false;

   double spread =
      (tick.ask - tick.bid) / _Point;

   return spread <= MaximumSpreadPoints;
}

//==============================================================
// MODULE 1 PATTERN DETECTION
//
// R1 -> OPST1 -> OPST2
//
// All three candles must be completed.
//==============================================================

bool FindModule1Setup(OPSTSetup &setup)
{
   CandleData r;
   CandleData first;
   CandleData second;

   if(!GetCandleData(
      _Symbol, TradingTimeframe, 3, r))
      return false;

   if(!GetCandleData(
      _Symbol, TradingTimeframe, 2, first))
      return false;

   if(!GetCandleData(
      _Symbol, TradingTimeframe, 1, second))
      return false;

   if(EnableBuy)
   {
      if(BuildModule1Setup(
         r,
         first,
         second,
         OPST_BUY,
         setup))
         return true;
   }

   if(EnableSell)
   {
      if(BuildModule1Setup(
         r,
         first,
         second,
         OPST_SELL,
         setup))
         return true;
   }

   return false;
}

//==============================================================
// MODULE 2 PATTERN DETECTION
//
// R1 -> R2 -> OPST1 -> OPST2 -> OPST3
//
// All five candles must be completed.
//==============================================================

bool FindModule2Setup(OPSTSetup &setup)
{
   CandleData r1;
   CandleData r2;

   CandleData first;
   CandleData second;
   CandleData third;

   if(!GetCandleData(
      _Symbol, TradingTimeframe, 5, r1))
      return false;

   if(!GetCandleData(
      _Symbol, TradingTimeframe, 4, r2))
      return false;

   if(!GetCandleData(
      _Symbol, TradingTimeframe, 3, first))
      return false;

   if(!GetCandleData(
      _Symbol, TradingTimeframe, 2, second))
      return false;

   if(!GetCandleData(
      _Symbol, TradingTimeframe, 1, third))
      return false;

   if(EnableBuy)
   {
      if(BuildModule2Setup(
         r1,
         r2,
         first,
         second,
         third,
         OPST_BUY,
         setup))
         return true;
   }

   if(EnableSell)
   {
      if(BuildModule2Setup(
         r1,
         r2,
         first,
         second,
         third,
         OPST_SELL,
         setup))
         return true;
   }

   return false;
}

//==============================================================
// FIND SELECTED STRATEGY
//==============================================================

bool FindTradingSetup(OPSTSetup &setup)
{
   ResetOPSTSetup(setup);

   if(SelectedStrategy == STRATEGY_MODULE_1)
      return FindModule1Setup(setup);

   if(SelectedStrategy == STRATEGY_MODULE_2)
      return FindModule2Setup(setup);

   return false;
}

//==============================================================
// ACTIVATE NEW SETUP
//==============================================================

bool ActivateSetup(OPSTSetup &setup)
{
   if(!setup.valid)
      return false;

   if(setup.setup_time == lastUsedSetupTime)
      return false;

   InitializeMTS(setup, activeMTS);

   if(!ConfirmMTS(setup, activeMTS))
      return false;

   setupActive = true;

   lastUsedSetupTime = setup.setup_time;

   Print("--------------------------------");
   Print("MTS*1 CONFIRMED");
   Print("Strategy: ", EnumToString(setup.strategy));
   Print("Direction: ", EnumToString(setup.direction));
   Print("MTS Level: ", setup.mts_level);
   Print("Entry Level: ", setup.entry_level);
   Print("Stop Loss: ", setup.stop_loss);
   Print("--------------------------------");

   return true;
}

//==============================================================
// FRESH RETEST DETECTION
//
// BUY approaches from above.
// SELL approaches from below.
//
// Prevents treating an initial crossing as a retest.
//==============================================================

bool DetectFreshRetest(
   MTSData &mts,
   double bid,
   double ask
)
{
   if(mts.state != MTS_CONFIRMED)
      return false;

   double tolerance =
      RetestTolerancePoints * _Point;

   if(previousBid <= 0.0 || previousAsk <= 0.0)
      return false;

   bool touched = false;

   if(mts.direction == OPST_BUY)
   {
      bool approachedFromAbove =
         previousAsk > mts.entry_level + tolerance;

      bool reachedLevel =
         ask <= mts.entry_level + tolerance;

      if(approachedFromAbove && reachedLevel)
         touched = true;
   }

   else if(mts.direction == OPST_SELL)
   {
      bool approachedFromBelow =
         previousBid < mts.entry_level - tolerance;

      bool reachedLevel =
         bid >= mts.entry_level - tolerance;

      if(approachedFromBelow && reachedLevel)
         touched = true;
   }

   if(touched)
   {
      mts.state = MTS_RETESTED;

      Print("FRESH MTS RETEST DETECTED.");

      return true;
   }

   return false;
}

//==============================================================
// MANAGE ACTIVE SETUP
//==============================================================

void ManageActiveSetup(MqlTick &tick)
{
   if(!setupActive)
      return;

   // Check invalidation before entry.
   if(CheckMTSInvalidation(
      tick.bid,
      tick.ask,
      activeMTS))
   {
      Print("SETUP INVALIDATED.");

      setupActive = false;

      return;
   }

   // Check spread.
   if(!IsSpreadAcceptable())
      return;

   // Detect genuine retest.
   if(DetectFreshRetest(
      activeMTS,
      tick.bid,
      tick.ask))
   {
      if(ExecuteOPSTTrade(activeMTS))
      {
         Print("TRADE SUCCESSFULLY EXECUTED.");

         setupActive = false;
      }
      else
      {
         Print("TRADE NOT EXECUTED. Setup remains active.");

         ResetRetest(activeMTS);
      }
   }
}

//==============================================================
// MAIN TICK FUNCTION
//==============================================================

void OnTick()
{
   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
      return;

   // Manage active setup on every market tick.
   if(setupActive)
   {
      ManageActiveSetup(tick);

      previousBid = tick.bid;
      previousAsk = tick.ask;

      return;
   }

   // Detect new completed candle.
   if(IsNewBar())
   {
      OPSTSetup setup;

      if(FindTradingSetup(setup))
      {
         ActivateSetup(setup);
      }
   }

   previousBid = tick.bid;
   previousAsk = tick.ask;
}

//==============================================================
// DEINITIALIZATION
//==============================================================

void OnDeinit(const int reason)
{
   Print("OPST MTS EA STOPPED.");

   Print("Deinitialization reason: ", reason);
}

