//+------------------------------------------------------------------+
//|                                                 UncleBeanAAA.mq4 |
//|                                                        UncleBean |
//|                         https://github.com/TheUncleWhoGrowsBeans |
//+------------------------------------------------------------------+
#property copyright "UncleBean"
#property link      "https://github.com/TheUncleWhoGrowsBeans"
#property version   "1.01"
#property strict
//+------------------------------------------------------------------+
#define LOG_LEVEL_INFO 0
#define LOG_LEVEL_DEBUG 1
#define PRICE_TREND_BUY  0
#define PRICE_TREND_SELL 1
#define PRICE_TREND_NONE -1
#define MFI_GREEN 0
#define MFI_BROWN 1
#define MFI_BLUE 2
#define MFI_PINK 3
#define MFI_NONE -1
//+------------------------------------------------------------------+
enum eBool{是=True, 否=False};
enum eTimeFrame{M1=1, M5=5, M15=15, M30=30, H1=60, H4=240, D1=1440};
enum eLogLevel{INFO=LOG_LEVEL_INFO, DEBUG=LOG_LEVEL_DEBUG};
//+------------------------------------------------------------------+
extern eLogLevel pLogLevel = LOG_LEVEL_INFO;  // 日志级别
extern string pSymbol = "EURUSD"; // 交易品种，多个用逗号分隔，如EURUSD,GBPUSD
extern eTimeFrame pTimeFrame = 60;  // 策略运行周期
extern int pMAPeriod = 14;  // 均线时间周期
extern eBool pOnlySwapPos = False;  // 只开正利息方向
extern double pOpenLots = 0.01;  // 开仓单位（手）
//+------------------------------------------------------------------+
string gSymbol[100];
int gSymbolCnt;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   //if(!StringToUpper(pSymbol)) return(INIT_FAILED);
   if(StringReplace(pSymbol, "，", ",") == -1) return(INIT_FAILED);
   if(StringReplace(pSymbol, " ", "") == -1) return(INIT_FAILED);
   gSymbolCnt = StringSplit(pSymbol, StringGetCharacter(",", 0), gSymbol);
   for(int i=0; i<gSymbolCnt; i++){
      OutputLog(LOG_LEVEL_INFO, gSymbol[i]);
   }
   OnTick();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   for(int i=0; i<gSymbolCnt; i++){
      RunStrategy(gSymbol[i], pOpenLots, pTimeFrame, pMAPeriod, pOnlySwapPos);
   }
   

  }
//+------------------------------------------------------------------+
//| 策略                                      |
//+------------------------------------------------------------------+
void RunStrategy(string symbol="EURUSD", double openLots=0.1, int timeFame=60, int maPeriod=14, bool onlySwapPos=False){
   
   bool xOpenBuy = True, xOpenSell = True;
   if(onlySwapPos){
      if(MarketInfo(symbol, MODE_SWAPLONG) <= 0) xOpenBuy = False;
      if(MarketInfo(symbol, MODE_SWAPSHORT) <= 0) xOpenSell = False;
   }
   
   double xMA1 = iMA(symbol, timeFame, maPeriod, 0, 0, 0, 1);
   double xClose1 = iClose(symbol, timeFame, 1);
   double xOpen1 = iOpen(symbol, timeFame, 1);

   int xPriceTrend = GetPriceTrend(symbol, timeFame, maPeriod);
   int xMFITrend = GetMFITrend(symbol, timeFame);
   
   int xTicket = -2;
   if(xMFITrend == MFI_GREEN){
      if(xClose1 > xMA1 && xOpen1 < xMA1){
          CloseOrder(symbol, OP_SELL);
          if(xOpenBuy) xTicket = CheckAndOpenOrder(symbol, OP_BUY, openLots);
      }else if(xClose1 < xMA1 && xOpen1 > xMA1){
          CloseOrder(symbol, OP_BUY);
          if(xOpenSell) xTicket = CheckAndOpenOrder(symbol, OP_SELL, openLots);
      }
   }else if(xMFITrend == MFI_PINK){
      if(xPriceTrend == PRICE_TREND_BUY){
         CloseOrder(symbol, OP_BUY);
      }else if(xPriceTrend == PRICE_TREND_SELL){
         CloseOrder(symbol, OP_SELL);
      }
   }
   
   if(xTicket > 0){
      OutputLog(LOG_LEVEL_INFO, "OrderOpen #" + IntegerToString(xTicket));
   }
}
//+------------------------------------------------------------------+
//| 开仓                                   |
//+------------------------------------------------------------------+
int CheckAndOpenOrder(string symbol, int orderType, double openLots){
   int xOrdersTotal = OrdersTotal();
   int xOrderCnt = 0;
   datetime xLastOpenTime=0;
   for(int i = 0; i < xOrdersTotal; i++){
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderSymbol() != symbol) continue;
      if(OrderType() != orderType) continue;
      if(OrderOpenTime() > xLastOpenTime) xLastOpenTime = OrderOpenTime();
      xOrderCnt++;
   }
   if(TimeCurrent() < xLastOpenTime + pTimeFrame * 60) return(0);
   
   double xOpenPrice = 0;
   if(orderType == OP_BUY) xOpenPrice = MarketInfo(symbol, MODE_ASK);
   if(orderType == OP_SELL) xOpenPrice = MarketInfo(symbol, MODE_BID);
   int xOrderTicket = OrderSend(symbol, orderType, openLots, xOpenPrice, 1, 0, 0);
   
   return(xOrderTicket);
}
//+------------------------------------------------------------------+
//| 平仓                                  |
//+------------------------------------------------------------------+
void CloseOrder(string symbol, int orderType){
   int xOrdersTotal = OrdersTotal();
   for(int i = 0; i < xOrdersTotal; i++){
      if(!OrderSelect(i, SELECT_BY_POS)) continue;
      if(OrderSymbol() != symbol) continue;
      if(OrderType() != orderType) continue;
      if(OrderProfit() < 0) continue;
      double xClosePrice = 0;
      if(orderType == OP_BUY) xClosePrice = MarketInfo(symbol, MODE_BID);
      if(orderType == OP_SELL) xClosePrice = MarketInfo(symbol, MODE_ASK);
      if(OrderClose(OrderTicket(), OrderLots(), xClosePrice, 1)){
         
      }
      
   }
}
//+------------------------------------------------------------------+
//| 获取价格趋势                                            |
//+------------------------------------------------------------------+
int GetPriceTrend(string symbol="EURUSD", int timeframe=60, int period=14, int shift=1){
   double xClose = iClose(symbol, timeframe, shift);
   double xOpen = iOpen(symbol, timeframe, shift);
    if(xClose > xOpen){
      return(PRICE_TREND_BUY);
   }else if(xClose < xOpen){
      return(PRICE_TREND_SELL);
   }else{
      return(PRICE_TREND_NONE);
   }
}
//+------------------------------------------------------------------+
//| 获取MFI趋势                                            |
//+------------------------------------------------------------------+
int GetMFITrend(string symbol="EURUSD", int timeframe=60, int shift=1){
   double xMFI1 = iBWMFI(symbol, timeframe, shift);
   double xMFI2 = iBWMFI(symbol, timeframe, shift + 1);
   long xVolume1 = iVolume(symbol, timeframe, shift);
   long xVolume2 = iVolume(symbol, timeframe, shift + 1);
   OutputLog(
      LOG_LEVEL_DEBUG, 
      "MFI1 = " + DoubleToStr(xMFI1, 6) + ", MFI2 = " + DoubleToStr(xMFI2, 6) + ", Volume1 = " + IntegerToString(xVolume1) + ", Volume2 = " + IntegerToString(xVolume2)
      );
   
   if(xMFI1 > xMFI2 && xVolume1 > xVolume2){
      return(MFI_GREEN);
   }else if(xMFI1 < xMFI2 && xVolume1 < xVolume2){
      return(MFI_BROWN);
   }else if(xMFI1 > xMFI2 && xVolume1 < xVolume2){
      return(MFI_BLUE);
   }else if(xMFI1 < xMFI2 && xVolume1 > xVolume2){
      return(MFI_PINK);
   }else{
      return(MFI_NONE);
   }
}
//+------------------------------------------------------------------+
//| 输出日志                                            |
//+------------------------------------------------------------------+
void OutputLog(int logLevel, string logContent){
   if(logLevel == LOG_LEVEL_DEBUG){
      if(pLogLevel == LOG_LEVEL_DEBUG){
         Print("[DEBUG]" + logContent);
      }
   }else{
      Print("[INFO]" + logContent);
   }
}