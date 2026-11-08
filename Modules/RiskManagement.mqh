
#ifndef RISK_MANAGEMENT_MQH
#define RISK_MANAGEMENT_MQH

//==============================================================
// OPST MTS EA - Risk Management
//==============================================================

input double RiskPercent = 1.0;
input double RiskRewardRatio = 2.0;

//==============================================================
// Calculate permitted monetary risk
//==============================================================

double CalculateRiskAmount()
{
   double balance =
      AccountInfoDouble(ACCOUNT_BALANCE);

   if(balance <= 0.0 || RiskPercent <= 0.0)
      return 0.0;

   return balance * RiskPercent / 100.0;
}

//==============================================================
// Calculate volume digits
//==============================================================

int GetVolumeDigits(double step)
{
   for(int digits = 0; digits <= 8; digits++)
   {
      if(MathAbs(
         step - NormalizeDouble(step, digits)
      ) < 1e-9)
         return digits;
   }

   return 8;
}

//==============================================================
// Calculate lot size using OrderCalcProfit
//==============================================================

double CalculateLotSize(
   string symbol,
   ENUM_ORDER_TYPE orderType,
   double entryPrice,
   double stopLoss
)
{
   double riskMoney = CalculateRiskAmount();

   if(riskMoney <= 0.0)
      return 0.0;

   if(entryPrice <= 0.0 || stopLoss <= 0.0)
      return 0.0;

   double stopDistance =
      MathAbs(entryPrice - stopLoss);

   if(stopDistance <= 0.0)
      return 0.0;

   double oneLotLoss = 0.0;

   if(!OrderCalcProfit(
      orderType,
      symbol,
      1.0,
      entryPrice,
      stopLoss,
      oneLotLoss
   ))
   {
      Print("OrderCalcProfit failed: ", GetLastError());
      return 0.0;
   }

   oneLotLoss = MathAbs(oneLotLoss);

   if(oneLotLoss <= 0.0)
      return 0.0;

   double rawVolume = riskMoney / oneLotLoss;

   double minVolume =
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   double maxVolume =
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   double volumeStep =
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(volumeStep <= 0.0 ||
      minVolume <= 0.0 ||
      maxVolume <= 0.0)
      return 0.0;

   // Round down to avoid exceeding the risk budget.
   double volume =
      MathFloor(rawVolume / volumeStep + 1e-9)
      * volumeStep;

   if(volume < minVolume)
   {
      Print("Trade skipped: minimum lot exceeds risk budget.");
      return 0.0;
   }

   volume = MathMin(volume, maxVolume);

   int digits = GetVolumeDigits(volumeStep);

   volume = NormalizeDouble(volume, digits);

   // Final risk verification.
   double actualLoss = 0.0;

   if(!OrderCalcProfit(
      orderType,
      symbol,
      volume,
      entryPrice,
      stopLoss,
      actualLoss
   ))
      return 0.0;

   if(MathAbs(actualLoss) > riskMoney + 0.01)
   {
      Print("Trade skipped: calculated risk exceeds budget.");
      return 0.0;
   }

   return volume;
}

//==============================================================
// Calculate Take Profit
//==============================================================

double CalculateTakeProfit(
   ENUM_OPST_DIRECTION direction,
   double entryPrice,
   double stopLoss
)
{
   if(RiskRewardRatio <= 0.0)
      return 0.0;

   double riskDistance =
      MathAbs(entryPrice - stopLoss);

   if(riskDistance <= 0.0)
      return 0.0;

   if(direction == OPST_BUY)
      return entryPrice +
             riskDistance * RiskRewardRatio;

   if(direction == OPST_SELL)
      return entryPrice -
             riskDistance * RiskRewardRatio;

   return 0.0;
}

//==============================================================
// Validate Stop Loss
//==============================================================

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

//==============================================================
// Validate Take Profit
//==============================================================

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
