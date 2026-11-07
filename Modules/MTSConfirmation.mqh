
#ifndef MTS_CONFIRMATION_MQH
#define MTS_CONFIRMATION_MQH

#include "OPSTValidation.mqh"

//+------------------------------------------------------------------+
//| MTS*1 State                                                      |
//+------------------------------------------------------------------+

enum ENUM_MTS_STATE
{
   MTS_WAITING = 0,
   MTS_CONFIRMED,
   MTS_RETESTED,
   MTS_INVALIDATED,
   MTS_CONSUMED
};

//+------------------------------------------------------------------+
//| MTS Setup State                                                  |
//+------------------------------------------------------------------+

struct MTSData
{
   ENUM_MTS_STATE state;

   ENUM_OPST_DIRECTION direction;

   double level;
   double stop_loss;

   datetime confirmation_time;
   datetime setup_time;

   bool trade_executed;
};

//+------------------------------------------------------------------+
//| Initialize MTS                                                   |
//+------------------------------------------------------------------+

void InitializeMTS(
   OPSTSetup &setup,
   MTSData &mts
)
{
   mts.state = MTS_WAITING;

   mts.direction = setup.direction;

   mts.level = setup.mts_level;
   mts.stop_loss = setup.stop_loss;

   mts.confirmation_time = setup.second_opst.time;
   mts.setup_time = setup.setup_time;

   mts.trade_executed = false;
}

//+------------------------------------------------------------------+
//| Confirm MTS*1                                                    |
//+------------------------------------------------------------------+

bool ConfirmMTS(
   OPSTSetup &setup,
   MTSData &mts
)
{
   if(!setup.valid)
      return false;

   if(mts.trade_executed)
      return false;

   if(mts.state != MTS_WAITING)
      return false;

   bool confirmed = false;

   if(setup.direction == OPST_BUY)
   {
      confirmed =
         setup.second_opst.close > setup.r_candle.open;
   }
   else if(setup.direction == OPST_SELL)
   {
      confirmed =
         setup.second_opst.close < setup.r_candle.open;
   }

   if(!confirmed)
      return false;

   mts.state = MTS_CONFIRMED;

   return true;
}

//+------------------------------------------------------------------+
//| Invalidate setup before entry                                    |
//+------------------------------------------------------------------+

bool CheckMTSInvalidation(
   double bid,
   double ask,
   MTSData &mts
)
{
   if(mts.state != MTS_CONFIRMED)
      return false;

   if(mts.direction == OPST_BUY)
   {
      if(bid <= mts.stop_loss)
      {
         mts.state = MTS_INVALIDATED;
         return true;
      }
   }
   else if(mts.direction == OPST_SELL)
   {
      if(ask >= mts.stop_loss)
      {
         mts.state = MTS_INVALIDATED;
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Mark setup as consumed                                           |
//+------------------------------------------------------------------+

void ConsumeMTS(MTSData &mts)
{
   mts.trade_executed = true;
   mts.state = MTS_CONSUMED;
}

#endif
