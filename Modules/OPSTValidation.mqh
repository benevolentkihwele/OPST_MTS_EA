
#ifndef OPST_VALIDATION_MQH
#define OPST_VALIDATION_MQH

#include "CandleDetection.mqh"

//+------------------------------------------------------------------+
//| OPST Setup Direction                                             |
//+------------------------------------------------------------------+

enum ENUM_OPST_DIRECTION
{
   OPST_SELL = -1,
   OPST_NONE = 0,
   OPST_BUY  = 1
};

//+------------------------------------------------------------------+
//| OPST Setup Information                                           |
//+------------------------------------------------------------------+

struct OPSTSetup
{
   bool valid;

   ENUM_OPST_DIRECTION direction;

   CandleData r_candle;
   CandleData first_opst;
   CandleData second_opst;

   double mts_level;
   double stop_loss;

   datetime setup_time;
};

//+------------------------------------------------------------------+
//| Check first OPST candle                                          |
//+------------------------------------------------------------------+

bool ValidateFirstOPST(
   CandleData &r,
   CandleData &first,
   ENUM_OPST_DIRECTION direction
)
{
   if(!IsValidCandle(r) || !IsValidCandle(first))
      return false;

   double midpoint = GetRBodyMidpoint(r);

   if(direction == OPST_BUY)
   {
      if(!IsBearishCandle(r))
         return false;

      if(!IsBullishCandle(first))
         return false;

      // First OPST must reach the 50% body level.
      if(first.low > midpoint)
         return false;

      // First OPST lower wick must be longer.
      if(first.lower_wick <= r.lower_wick)
         return false;
   }
   else if(direction == OPST_SELL)
   {
      if(!IsBullishCandle(r))
         return false;

      if(!IsBearishCandle(first))
         return false;

      // First OPST must reach the 50% body level.
      if(first.high < midpoint)
         return false;

      // First OPST upper wick must be longer.
      if(first.upper_wick <= r.upper_wick)
         return false;
   }
   else
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check second OPST candle                                         |
//+------------------------------------------------------------------+

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

      // Close must be above bearish R opening price.
      if(second.close <= r.open)
         return false;
   }
   else if(direction == OPST_SELL)
   {
      if(!IsBearishCandle(second))
         return false;

      // Close must be below bullish R opening price.
      if(second.close >= r.open)
         return false;
   }
   else
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Build a validated OPST setup                                     |
//+------------------------------------------------------------------+

bool BuildOPSTSetup(
   CandleData &r,
   CandleData &first,
   CandleData &second,
   ENUM_OPST_DIRECTION direction,
   OPSTSetup &setup
)
{
   setup.valid = false;

   if(!ValidateFirstOPST(r, first, direction))
      return false;

   if(!ValidateSecondOPST(r, second, direction))
      return false;

   setup.direction = direction;

   setup.r_candle = r;
   setup.first_opst = first;
   setup.second_opst = second;

   // MTS*1 is the R candle opening price.
   setup.mts_level = r.open;

   // BUY SL below first OPST low.
   // SELL SL above first OPST high.
   if(direction == OPST_BUY)
      setup.stop_loss = first.low;
   else
      setup.stop_loss = first.high;

   setup.setup_time = second.time;

   setup.valid = true;

   return true;
}

#endif
