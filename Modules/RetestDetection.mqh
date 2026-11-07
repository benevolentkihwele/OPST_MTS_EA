
#ifndef RETEST_DETECTION_MQH
#define RETEST_DETECTION_MQH

#include "MTSConfirmation.mqh"

//+------------------------------------------------------------------+
//| Detect MTS*1 Retest                                              |
//+------------------------------------------------------------------+

bool DetectMTSRetest(
   MTSData &mts,
   double bid,
   double ask
)
{
   if(mts.state != MTS_CONFIRMED)
      return false;

   if(mts.trade_executed)
      return false;

   bool touched = false;

   // BUY: Price returns downward to MTS*1.
   if(mts.direction == OPST_BUY)
   {
      if(ask <= mts.level)
         touched = true;
   }

   // SELL: Price returns upward to MTS*1.
   else if(mts.direction == OPST_SELL)
   {
      if(bid >= mts.level)
         touched = true;
   }

   if(touched)
   {
      mts.state = MTS_RETESTED;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Reset retest state                                               |
//+------------------------------------------------------------------+

void ResetRetest(MTSData &mts)
{
   if(mts.state == MTS_RETESTED)
      mts.state = MTS_CONFIRMED;
}

#endif
