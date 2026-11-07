
#ifndef CANDLE_DETECTION_MQH
#define CANDLE_DETECTION_MQH

//+------------------------------------------------------------------+
//| Candle Detection Module                                          |
//| OPST + MTS*1 Expert Advisor                                      |
//+------------------------------------------------------------------+

enum ENUM_CANDLE_DIRECTION
{
   CANDLE_BEARISH = -1,
   CANDLE_DOJI   = 0,
   CANDLE_BULLISH = 1
};

// Candle information structure
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

//+------------------------------------------------------------------+
//| Load candle data                                                 |
//+------------------------------------------------------------------+
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

   return true;
}

//+------------------------------------------------------------------+
//| Check bullish candle                                             |
//+------------------------------------------------------------------+
bool IsBullishCandle(CandleData &candle)
{
   return candle.direction == CANDLE_BULLISH;
}

//+------------------------------------------------------------------+
//| Check bearish candle                                             |
//+------------------------------------------------------------------+
bool IsBearishCandle(CandleData &candle)
{
   return candle.direction == CANDLE_BEARISH;
}

//+------------------------------------------------------------------+
//| Calculate R candle body midpoint                                 |
//+------------------------------------------------------------------+
double GetRBodyMidpoint(CandleData &candle)
{
   return (candle.open + candle.close) / 2.0;
}

//+------------------------------------------------------------------+
//| Validate candle data                                             |
//+------------------------------------------------------------------+
bool IsValidCandle(CandleData &candle)
{
   if(candle.high <= candle.low)
      return false;

   if(candle.body_size < 0)
      return false;

   if(candle.upper_wick < 0 || candle.lower_wick < 0)
      return false;

   return true;
}

#endif
