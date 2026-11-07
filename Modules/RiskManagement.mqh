
#ifndef RISK_MANAGEMENT_MQH
#define RISK_MANAGEMENT_MQH

//+------------------------------------------------------------------+
//| Risk Management Module                                           |
//| OPST + MTS*1 Expert Advisor                                      |
//+------------------------------------------------------------------+

// Default risk settings
input double RiskPercent = 1.0;
input double RiskRewardRatio = 2.0;

//+------------------------------------------------------------------+
//| Calculate risk amount                                            |
//+------------------------------------------------------------------+

double CalculateRiskAmount(string symbol)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(balance <= 0.0 || RiskPercent <= 0.0)
      return 0.0;

   return balance * (RiskPercent / 100.0);
}

//+------------------------------------------------------------------+
//| Calculate lot size                                               |
//+------------------------------------------------------------------+

double CalculateLotSize(
   string symbol,
   double entryPrice,
   double stopLoss
)
{
   double riskAmount = CalculateRiskAmount(symbol);

   if(riskAmount <= 0.0)
      return 0.0;

   double tickSize =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

   double tickValueLoss =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);

   double minLot =
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   double maxLot =
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   double lotStep =
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   double stopDistance = MathAbs(entryPrice - stopLoss);

   if(tickSize <= 0.0 ||
      tickValueLoss <= 0.0 ||
      stopDistance <= 0.0 ||
      lotStep <= 0.0)
      return 0.0;

   // Monetary risk for one lot.
   double lossPerLot =
      (stopDistance / tickSize) * tickValueLoss;

   if(lossPerLot <= 0.0)
      return 0.0;

   double rawLot = riskAmount / lossPerLot;

   // Round DOWN to avoid exceeding intended risk.
   double lot =
      MathFloor(rawLot / lotStep + 1e-8) * lotStep;

   // Never force the broker's minimum lot if it exceeds risk.
   if(lot < minLot)
      return 0.0;

   lot = MathMin(lot, maxLot);

   int volumeDigits = 0;
   double step = lotStep;

   while(volumeDigits < 8 &&
         MathAbs(step - MathRound(step)) > 1e-8)
   {
      step *= 10.0;
      volumeDigits++;
   }

   return NormalizeDouble(lot, volumeDigits);
}

//+------------------------------------------------------------------+
//| Calculate take profit                                            |
//+------------------------------------------------------------------+

double CalculateTakeProfit(
   ENUM_OPST_DIRECTION direction,
   double entryPrice,
   double stopLoss
)
{
   if(RiskRewardRatio <= 0.0)
      return 0.0;

   double riskDistance = MathAbs(entryPrice - stopLoss);

   if(riskDistance <= 0.0)
      return 0.0;

   if(direction == OPST_BUY)
      return entryPrice + (riskDistance * RiskRewardRatio);

   if(direction == OPST_SELL)
      return entryPrice - (riskDistance * RiskRewardRatio);

   return 0.0;
}

//+------------------------------------------------------------------+
//| Validate stop loss                                               |
//+------------------------------------------------------------------+

bool ValidateStopLoss(
   ENUM_OPST_DIRECTION direction,
   double entryPrice,
   double stopLoss
)
{
   if(entryPrice <= 0.0 || stopLoss <= 0.0)
      return false;

   if(direction == OPST_BUY)
      return stopLoss < entryPrice;

   if(direction == OPST_SELL)
      return stopLoss > entryPrice;

   return false;
}

//+------------------------------------------------------------------+
//| Validate take profit                                             |
//+------------------------------------------------------------------+

bool ValidateTakeProfit(
   ENUM_OPST_DIRECTION direction,
   double entryPrice,
   double takeProfit
)
{
   if(entryPrice <= 0.0 || takeProfit <= 0.0)
      return false;

   if(direction == OPST_BUY)
      return takeProfit > entryPrice;

   if(direction == OPST_SELL)
      return takeProfit < entryPrice;

   return false;
}

#endif
