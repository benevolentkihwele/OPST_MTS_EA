
#ifndef RETEST_DETECTION_MQH
#define RETEST_DETECTION_MQH

#include "MTSConfirmation.mqh"

//==============================================================
// Retest settings
//==============================================================

input int RetestTolerancePoints = 5;

//==============================================================
// Check whether price touches a level
//==============================================================

bool IsPriceTouching(
   double price,
   double level,
   double tolerance
)
{
   return MathAbs(price - level) <= tolerance;
}

//==============================================================
// Detect retest
//==============================================================

bool DetectMTSRetest(
   MTSData &mts,
   double bid,
   double ask,
   double point
)
{
   if(mts.state != MTS_CONFIRMED)
      return false;

   if(mts.trade_executed)
      return false;

   if(point <= 0.0)
      return false;

   double tolerance =
      RetestTolerancePoints * point;

   double entry = mts.entry_level;

   bool touched = false;

   // BUY: price approaches entry from above.
   if(mts.direction == OPST_BUY)
   {
      touched =
         ask <= entry + tolerance &&
         ask >= entry - tolerance;
   }

   // SELL: price approaches entry from below.
   else if(mts.direction == OPST_SELL)
   {
      touched =
         bid >= entry - tolerance &&
         bid <= entry + tolerance;
   }

   if(!touched)
      return false;

   mts.state = MTS_RETESTED;

   return true;
}

//==============================================================
// Reset retest state after failed execution
//==============================================================

void ResetRetest(MTSData &mts)
{
   if(mts.state == MTS_RETESTED &&
      !mts.trade_executed)
   {
      mts.state = MTS_CONFIRMED;
   }
}

#endif
