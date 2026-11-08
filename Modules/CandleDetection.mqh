
#ifndef CANDLE_DETECTION_MQH
#define CANDLE_DETECTION_MQH

//==============================================================
// OPST MTS EA - Candle Detection Module
//==============================================================

enum ENUM_CANDLE_DIRECTION
{
   CANDLE_BEARISH = -1,
   CANDLE_DOJI    = 0,
   CANDLE_BULLISH = 1
};

struct CandleData
{
   datetime time;

   double open;
   double close;
   double high;
   double low;

   double body_size;
   double upper_wick;
   double lower_wick;

   double body_midpoint;

   ENUM_CANDLE_DIRECTION direction;
};

//==============================================================
// Load candle data
//==============================================================

bool GetCandleData(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift,
   CandleData &candle
)
{
   MqlRates rates[];

   ArraySetAsSeries(rates, true);

   if(CopyRates(symbol, timeframe, shift, 1, rates) != 1)
      return false;

   candle.time  = rates[0].time;
   candle.open  = rates[0].open;
   candle.close = rates[0].close;
   candle.high  = rates[0].high;
   candle.low   = rates[0].low;

   candle.body_size =
      MathAbs(candle.close - candle.open);

   candle.upper_wick =
      candle.high - MathMax(candle.open, candle.close);

   candle.lower_wick =
      MathMin(candle.open, candle.close) - candle.low;

   candle.body_midpoint =
      (candle.open + candle.close) / 2.0;

   if(candle.close > candle.open)
      candle.direction = CANDLE_BULLISH;
   else if(candle.close < candle.open)
      candle.direction = CANDLE_BEARISH;
   else
      candle.direction = CANDLE_DOJI;

   return IsValidCandle(candle);
}

//==============================================================
// Validate candle
//==============================================================

bool IsValidCandle(CandleData &candle)
{
   if(candle.high <= candle.low)
      return false;

   if(candle.body_size < 0.0)
      return false;

   if(candle.upper_wick < 0.0)
      return false;

   if(candle.lower_wick < 0.0)
      return false;

   return true;
}

//==============================================================
// Candle direction checks
//==============================================================

bool IsBullishCandle(CandleData &candle)
{
   return candle.close > candle.open;
}

bool IsBearishCandle(CandleData &candle)
{
   return candle.close < candle.open;
}

bool IsDojiCandle(CandleData &candle)
{
   return candle.close == candle.open;
}

//==============================================================
// Candle measurements
//==============================================================

double GetCandleBodyMidpoint(CandleData &candle)
{
   return (candle.open + candle.close) / 2.0;
}

double GetLowerWick(CandleData &candle)
{
   return candle.lower_wick;
}

double GetUpperWick(CandleData &candle)
{
   return candle.upper_wick;
}

double GetCandleRange(CandleData &candle)
{
   return candle.high - candle.low;
}

//==============================================================
// Check whether candle reaches R body midpoint
//==============================================================

bool TouchesBodyMidpoint(
   CandleData &r,
   CandleData &opst,
   bool bullishSetup
)
{
   double midpoint = GetCandleBodyMidpoint(r);

   if(bullishSetup)
      return opst.low <= midpoint;

   return opst.high >= midpoint;
}

//==============================================================
// Compare directional wicks
//==============================================================

bool ValidateDirectionalWick(
   CandleData &r,
   CandleData &opst,
   bool bullishSetup
)
{
   if(bullishSetup)
      return opst.lower_wick > r.lower_wick;

   return opst.upper_wick > r.upper_wick;
}

//==============================================================
// Check completed candle
//==============================================================

bool IsCompletedCandle(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int shift
)
{
   if(shift < 1)
      return false;

   datetime candleTime =
      iTime(symbol, timeframe, shift);

   if(candleTime == 0)
      return false;

   return true;
}

#endif
