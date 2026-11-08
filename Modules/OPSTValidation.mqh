
#ifndef OPST_VALIDATION_MQH
#define OPST_VALIDATION_MQH

#include "CandleDetection.mqh"

//==============================================================
// Strategy selection
//==============================================================

enum ENUM_OPST_STRATEGY
{
   STRATEGY_MODULE_1 = 1,
   STRATEGY_MODULE_2 = 2
};

//==============================================================
// Trading direction
//==============================================================

enum ENUM_OPST_DIRECTION
{
   OPST_SELL = -1,
   OPST_NONE = 0,
   OPST_BUY  = 1
};

//==============================================================
// Setup information
//==============================================================

struct OPSTSetup
{
   bool valid;

   ENUM_OPST_STRATEGY strategy;
   ENUM_OPST_DIRECTION direction;

   CandleData r1;
   CandleData r2;

   CandleData opst1;
   CandleData opst2;
   CandleData opst3;

   double mts_level;
   double entry_level;
   double stop_loss;

   datetime setup_time;
};

//==============================================================
// Reset setup
//==============================================================

void ResetOPSTSetup(OPSTSetup &setup)
{
   setup.valid = false;

   setup.strategy = STRATEGY_MODULE_1;
   setup.direction = OPST_NONE;

   setup.mts_level = 0.0;
   setup.entry_level = 0.0;
   setup.stop_loss = 0.0;

   setup.setup_time = 0;
}

//==============================================================
// Validate R candle
//==============================================================

bool ValidateRCandle(
   CandleData &r,
   ENUM_OPST_DIRECTION direction
)
{
   if(!IsValidCandle(r))
      return false;

   if(direction == OPST_BUY)
      return IsBearishCandle(r);

   if(direction == OPST_SELL)
      return IsBullishCandle(r);

   return false;
}

//==============================================================
// Validate first OPST
//==============================================================

bool ValidateFirstOPST(
   CandleData &r,
   CandleData &first,
   ENUM_OPST_DIRECTION direction
)
{
   if(!IsValidCandle(r) || !IsValidCandle(first))
      return false;

   if(direction == OPST_BUY)
   {
      if(!IsBullishCandle(first))
         return false;

      if(!TouchesBodyMidpoint(r, first, true))
         return false;

      if(!ValidateDirectionalWick(r, first, true))
         return false;
   }
   else if(direction == OPST_SELL)
   {
      if(!IsBearishCandle(first))
         return false;

      if(!TouchesBodyMidpoint(r, first, false))
         return false;

      if(!ValidateDirectionalWick(r, first, false))
         return false;
   }
   else
   {
      return false;
   }

   return true;
}

//==============================================================
// Validate second OPST for Module 1
//==============================================================

bool ValidateSecondOPST(
   CandleData &r,
   CandleData &second,
   ENUM_OPST_DIRECTION direction
)
{
   if(!IsValidCandle(r) || !IsValidCandle(second))
      return false;

   if(direction == OPST_BUY)
   {
      if(!IsBullishCandle(second))
         return false;

      return second.close > r.open;
   }

   if(direction == OPST_SELL)
   {
      if(!IsBearishCandle(second))
         return false;

      return second.close < r.open;
   }

   return false;
}

//==============================================================
// Build Module 1 setup
//==============================================================

bool BuildModule1Setup(
   CandleData &r,
   CandleData &first,
   CandleData &second,
   ENUM_OPST_DIRECTION direction,
   OPSTSetup &setup
)
{
   ResetOPSTSetup(setup);

   if(!ValidateRCandle(r, direction))
      return false;

   if(!ValidateFirstOPST(r, first, direction))
      return false;

   if(!ValidateSecondOPST(r, second, direction))
      return false;

   setup.strategy = STRATEGY_MODULE_1;
   setup.direction = direction;

   setup.r1 = r;
   setup.opst1 = first;
   setup.opst2 = second;

   setup.mts_level = r.open;

   // Module 1 entry: MTS*1 retest.
   setup.entry_level = r.open;

   // Stop loss: first OPST wick.
   if(direction == OPST_BUY)
      setup.stop_loss = first.low;
   else
      setup.stop_loss = first.high;

   setup.setup_time = second.time;

   setup.valid = true;

   return true;
}

//==============================================================
// Validate two R candles for Module 2
//==============================================================

bool ValidateTwoRCandles(
   CandleData &r1,
   CandleData &r2,
   ENUM_OPST_DIRECTION direction
)
{
   if(!ValidateRCandle(r1, direction))
      return false;

   if(!ValidateRCandle(r2, direction))
      return false;

   // R2 must be newer than R1.
   if(r2.time <= r1.time)
      return false;

   return true;
}

//==============================================================
// Validate Module 2 OPST direction
//==============================================================

bool ValidateModule2Directions(
   CandleData &first,
   CandleData &second,
   CandleData &third,
   ENUM_OPST_DIRECTION direction
)
{
   if(!IsValidCandle(first) ||
      !IsValidCandle(second) ||
      !IsValidCandle(third))
      return false;

   if(first.time >= second.time ||
      second.time >= third.time)
      return false;

   if(direction == OPST_BUY)
   {
      return IsBullishCandle(first) &&
             IsBullishCandle(second) &&
             IsBullishCandle(third);
   }

   if(direction == OPST_SELL)
   {
      return IsBearishCandle(first) &&
             IsBearishCandle(second) &&
             IsBearishCandle(third);
   }

   return false;
}

//==============================================================
// Check Module 2 midpoint condition
// Either OPST1 or both OPST1 and OPST2
// must reach the R candle body midpoint.
//==============================================================

bool ValidateModule2Midpoint(
   CandleData &r1,
   CandleData &r2,
   CandleData &first,
   CandleData &second,
   ENUM_OPST_DIRECTION direction
)
{
   bool touchR1 = TouchesBodyMidpoint(
      r1, first, direction == OPST_BUY
   );

   bool touchR2 = TouchesBodyMidpoint(
      r2, first, direction == OPST_BUY
   );

   bool firstTouchesBoth = touchR1 && touchR2;

   bool secondTouchesBoth =
      TouchesBodyMidpoint(r1, second, direction == OPST_BUY) &&
      TouchesBodyMidpoint(r2, second, direction == OPST_BUY);

   // Accept first OPST reaching both levels,
   // or both first and second OPST reaching them.
   return firstTouchesBoth ||
          (touchR1 && touchR2 && secondTouchesBoth);
}

//==============================================================
// Build Module 2 setup
//==============================================================

bool BuildModule2Setup(
   CandleData &r1,
   CandleData &r2,
   CandleData &first,
   CandleData &second,
   CandleData &third,
   ENUM_OPST_DIRECTION direction,
   OPSTSetup &setup
)
{
   ResetOPSTSetup(setup);

   if(!ValidateTwoRCandles(r1, r2, direction))
      return false;

   if(!ValidateModule2Directions(
      first, second, third, direction))
      return false;

   if(!ValidateModule2Midpoint(
      r1, r2, first, second, direction))
      return false;

   // Second R candle must precede the OPST sequence.
   if(r2.time >= first.time)
      return false;

   // MTS*1 uses the second R candle opening price.
   double mts = r2.open;

   // Third OPST must close beyond MTS*1.
   if(direction == OPST_BUY && third.close <= mts)
      return false;

   if(direction == OPST_SELL && third.close >= mts)
      return false;

   setup.strategy = STRATEGY_MODULE_2;
   setup.direction = direction;

   setup.r1 = r1;
   setup.r2 = r2;

   setup.opst1 = first;
   setup.opst2 = second;
   setup.opst3 = third;

   setup.mts_level = mts;

   // Entry at the second OPST wick.
   if(direction == OPST_BUY)
   {
      setup.entry_level = second.low;
      setup.stop_loss = first.low;
   }
   else
   {
      setup.entry_level = second.high;
      setup.stop_loss = first.high;
   }

   setup.setup_time = third.time;

   setup.valid = true;

   return true;
}

#endif
