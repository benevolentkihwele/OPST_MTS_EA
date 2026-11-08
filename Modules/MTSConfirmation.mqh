
#ifndef MTS_CONFIRMATION_MQH
#define MTS_CONFIRMATION_MQH

#include "OPSTValidation.mqh"

//==============================================================
// MTS states
//==============================================================

enum ENUM_MTS_STATE
{
   MTS_WAITING = 0,
   MTS_CONFIRMED,
   MTS_RETESTED,
   MTS_INVALIDATED,
   MTS_CONSUMED
};

//==============================================================
// MTS tracking structure
//==============================================================

struct MTSData
{
   ENUM_MTS_STATE state;

   ENUM_OPST_STRATEGY strategy;
   ENUM_OPST_DIRECTION direction;

   double level;
   double entry_level;
   double stop_loss;

   datetime confirmation_time;
   datetime setup_time;

   bool trade_executed;
};

//==============================================================
// Initialize MTS
//==============================================================

void InitializeMTS(
   OPSTSetup &setup,
   MTSData &mts
)
{
   mts.state = MTS_WAITING;

   mts.strategy = setup.strategy;
   mts.direction = setup.direction;

   mts.level = setup.mts_level;
   mts.entry_level = setup.entry_level;
   mts.stop_loss = setup.stop_loss;

   mts.confirmation_time = setup.setup_time;
   mts.setup_time = setup.setup_time;

   mts.trade_executed = false;
}

//==============================================================
// Confirm MTS
//==============================================================

bool ConfirmMTS(
   OPSTSetup &setup,
   MTSData &mts
)
{
   if(!setup.valid)
      return false;

   if(mts.state != MTS_WAITING)
      return false;

   bool confirmed = false;

   if(setup.strategy == STRATEGY_MODULE_1)
   {
      if(setup.direction == OPST_BUY)
         confirmed = setup.opst2.close > setup.r1.open;

      else if(setup.direction == OPST_SELL)
         confirmed = setup.opst2.close < setup.r1.open;
   }

   else if(setup.strategy == STRATEGY_MODULE_2)
   {
      if(setup.direction == OPST_BUY)
         confirmed = setup.opst3.close > setup.mts_level;

      else if(setup.direction == OPST_SELL)
         confirmed = setup.opst3.close < setup.mts_level;
   }

   if(!confirmed)
      return false;

   mts.state = MTS_CONFIRMED;

   return true;
}

//==============================================================
// Check setup invalidation before entry
//==============================================================

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

//==============================================================
// Consume setup after successful trade
//==============================================================

void ConsumeMTS(MTSData &mts)
{
   mts.trade_executed = true;
   mts.state = MTS_CONSUMED;
}

//==============================================================
// Check active setup
//==============================================================

bool IsMTSActive(MTSData &mts)
{
   return (
      mts.state == MTS_CONFIRMED &&
      !mts.trade_executed
   );
}

#endif
