
#ifndef TRADE_EXECUTION_MQH
#define TRADE_EXECUTION_MQH

#include <Trade/Trade.mqh>
#include "RiskManagement.mqh"

//+------------------------------------------------------------------+
//| Trade execution settings                                         |
//+------------------------------------------------------------------+

input ulong MagicNumber = 20261107;
input int MaxSlippagePoints = 20;

CTrade trade;

//+------------------------------------------------------------------+
//| Initialize trade engine                                          |
//+------------------------------------------------------------------+

void InitializeTradeEngine()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
}

//+------------------------------------------------------------------+
//| Check existing EA position                                       |
//+------------------------------------------------------------------+

bool HasOpenEAPosition(string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Execute OPST trade                                               |
//+------------------------------------------------------------------+

bool ExecuteOPSTTrade(MTSData &mts)
{
   if(mts.state != MTS_RETESTED)
      return false;

   if(mts.trade_executed)
      return false;

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("Trading is not permitted.");
      return false;
   }

   string symbol = _Symbol;

   if(HasOpenEAPosition(symbol))
   {
      Print("Existing EA position found. Trade skipped.");
      return false;
   }

   MqlTick tick;

   if(!SymbolInfoTick(symbol, tick))
      return false;

   ENUM_OPST_DIRECTION direction = mts.direction;

   double entryPrice = 0.0;

   if(direction == OPST_BUY)
      entryPrice = tick.ask;
   else if(direction == OPST_SELL)
      entryPrice = tick.bid;
   else
      return false;

   double stopLoss = mts.stop_loss;

   if(!ValidateStopLoss(direction, entryPrice, stopLoss))
   {
      Print("Invalid Stop Loss.");
      return false;
   }

   double takeProfit = CalculateTakeProfit(
      direction,
      entryPrice,
      stopLoss
   );

   if(!ValidateTakeProfit(direction, entryPrice, takeProfit))
   {
      Print("Invalid Take Profit.");
      return false;
   }

   double lotSize = CalculateLotSize(
      symbol,
      entryPrice,
      stopLoss
   );

   if(lotSize <= 0.0)
   {
      Print("Calculated lot size is invalid or below broker minimum.");
      return false;
   }

   int digits = (int)SymbolInfoInteger(
      symbol,
      SYMBOL_DIGITS
   );

   stopLoss = NormalizeDouble(stopLoss, digits);
   takeProfit = NormalizeDouble(takeProfit, digits);

   bool result = false;

   if(direction == OPST_BUY)
   {
      result = trade.Buy(
         lotSize,
         symbol,
         0.0,
         stopLoss,
         takeProfit,
         "OPST MTS BUY"
      );
   }
   else if(direction == OPST_SELL)
   {
      result = trade.Sell(
         lotSize,
         symbol,
         0.0,
         stopLoss,
         takeProfit,
         "OPST MTS SELL"
      );
   }

   uint retcode = trade.ResultRetcode();

   if(!result ||
      (retcode != TRADE_RETCODE_DONE &&
       retcode != TRADE_RETCODE_DONE_PARTIAL &&
       retcode != TRADE_RETCODE_PLACED))
   {
      Print(
         "Trade execution failed: ",
         trade.ResultRetcodeDescription()
      );

      return false;
   }

   Print(
      "OPST trade accepted. Direction: ",
      direction,
      " | Volume: ",
      lotSize,
      " | SL: ",
      stopLoss,
      " | TP: ",
      takeProfit
   );

   ConsumeMTS(mts);

   return true;
}

#endif
