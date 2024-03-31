//+------------------------------------------------------------------+
//|                                                        RsiEA.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include                                |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>


//+------------------------------------------------------------------+
//| Inputs                                 |
//+------------------------------------------------------------------+
static input long     InpMagicNumber  = 5555;      //magic number
static input double   InpLotSize      = 0.01;          //lot size
input int             InpRSIPeriod    = 21;          //rsi period
input int             inpRSILevel     = 70;           //rsi level (upper )
input int             InpStopLoss     = 200;          //stop loss in point (0=off)
input int             InpTakeProfit   = 100;        // take profit in points (0=off)
input bool            InpCloseSignal  = false;     // close trades by opposite signal

//+------------------------------------------------------------------+
//| Global variables                              |
//+------------------------------------------------------------------+
int      handle;
double   buffer[];
MqlTick  currentTick;
CTrade trade;
datetime openTimeBuy = 0;
datetime openTimeSell = 0;






int OnInit()
  {
   //check user Input
   
   if(InpMagicNumber<=0)
   {
     Alert("Magicnumber <= 0");
     return INIT_PARAMETERS_INCORRECT;
   }
   
   
   if(InpLotSize<=0 || InpLotSize>10)
   {
     Alert("Input Lot size <= 0");
     return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpRSIPeriod<=1 )
   {
     Alert("RSI period cannot be < 1");
     return INIT_PARAMETERS_INCORRECT;
   }
   
   if(inpRSILevel >=100 || inpRSILevel<=50)
   {
     Alert("RSI level >=100 or <=50");
     return INIT_PARAMETERS_INCORRECT;
   }
       
    if(InpStopLoss<0)
   {
     Alert("IStop loss <0");
     return INIT_PARAMETERS_INCORRECT;
   }
   
    if(InpTakeProfit<0)
   {
     Alert("Take profit < 0");
     return INIT_PARAMETERS_INCORRECT;
   }
      
   
   // set magic number to trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // create rsi handle
   handle = iRSI(_Symbol,PERIOD_CURRENT,InpRSIPeriod,PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
   {
   Alert("Failed to create indicator handle");
   return INIT_FAILED;
   }
   
   // set buffer as series
   ArraySetAsSeries(buffer,true); 
   
   
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    //Release indicator handle
    if(handle != INVALID_HANDLE){IndicatorRelease(handle);}
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    //get current tick
    if(!SymbolInfoTick(_Symbol,currentTick)){Print("Failed to get current tick"); return;}
    
    // get resi values 
    int values = CopyBuffer(handle,0,0,2,buffer);
    if(values != 2)
    {
    Print("Failed to get indicator");
    return;
    }
    
    Comment("buffer[0]:",buffer[0],
    "\nbuffer[1]",buffer[1]
    );
    
    //Count open positions
    int cntBuy, cntSell;
    if(!CountOpenPosition(cntBuy,cntSell)){return;}
    
    // check for buy position
    if(cntBuy ==0 && buffer[1]>=(100-inpRSILevel) && buffer[0]<(100-inpRSILevel) && openTimeBuy !=iTime(_Symbol,PERIOD_CURRENT,0)){
    
    openTimeBuy = iTime(_Symbol,PERIOD_CURRENT,0);
    if(InpCloseSignal){if(!CountClosePositions(2)){return;}}
    double sl = InpStopLoss== 0 ? 0 :currentTick.bid - InpStopLoss* _Point;
    double tp = InpTakeProfit== 0 ? 0 :currentTick.bid + InpTakeProfit* _Point;
    if(!NormalizePrice(sl)){return;}
    if(!NormalizePrice(tp)){return;}
    trade.PositionOpen(_Symbol,ORDER_TYPE_BUY, InpLotSize,currentTick.ask,sl,tp,"RSI EA");
    }
    
     // check for sell position
    if(cntSell ==0 && buffer[1]<=inpRSILevel && buffer[0]>inpRSILevel && openTimeSell !=iTime(_Symbol,PERIOD_CURRENT,0)){
    
    openTimeSell = iTime(_Symbol,PERIOD_CURRENT,0);
    if(InpCloseSignal){if(!CountClosePositions(1)){return;}}
    double sl = InpStopLoss== 0 ? 0 :currentTick.ask + InpStopLoss* _Point;
    double tp = InpTakeProfit== 0 ? 0 :currentTick.ask - InpTakeProfit* _Point;
    if(!NormalizePrice(sl)){return;}
    if(!NormalizePrice(tp)){return;}
    trade.PositionOpen(_Symbol,ORDER_TYPE_SELL, InpLotSize,currentTick.bid,sl,tp,"RSI EA");
    }

  }
  
  //+------------------------------------------------------------------+
//| Custom funtions                                        |
//+------------------------------------------------------------------+

//count open positions

bool CountOpenPosition(int &cntBuy, int &cntSell)
{

  cntBuy = 0;
  cntSell = 0;
  int total = PositionsTotal();
  for(int i=total-1; i>=0; i--){
  ulong ticket = PositionGetTicket(i);
  if(ticket <= 0){Print("Failed to get position ticket"); return false;}
  if(!PositionSelectByTicket(ticket)){Print("Failed to select position ticket"); return false;}
  long magic;
  if(!PositionGetInteger(POSITION_MAGIC,magic)){Print("Failed toget position magic number"); return false;}
  if(magic == InpMagicNumber){
    long type;
    if(!PositionGetInteger(POSITION_TYPE,type)){Print("Failed to get position type"); return false;}
    if(type==POSITION_TYPE_BUY){cntBuy++;}
    if(type == POSITION_TYPE_SELL){cntSell++;}
   }
  }
 return true;
}



//Normalize price

bool NormalizePrice(double &price)
{
  double tickSize = 0;
  if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,tickSize)){Print("Failed to get tick size"); return false;}
  price = NormalizeDouble(MathRound(price/tickSize)*tickSize,_Digits);
 return true;
}

//Close positions
bool CountClosePositions(int all_buy_sell)
{

//---

  int total = PositionsTotal();
  for(int i=total-1; i>=0; i--){
  ulong ticket = PositionGetTicket(i);
  if(ticket <= 0){Print("Failed to get position ticket"); return false;}
  if(!PositionSelectByTicket(ticket)){Print("Failed to select position ticket"); return false;}
  long magic;
  if(!PositionGetInteger(POSITION_MAGIC,magic)){Print("Failed toget position magic number"); return false;}
  if(magic == InpMagicNumber){
    long type;
    if(!PositionGetInteger(POSITION_TYPE,type)){Print("Failed to get position type"); return false;}
    if(all_buy_sell == 1 && type == POSITION_TYPE_SELL){continue;}
    if(all_buy_sell == 2 && type == POSITION_TYPE_BUY){continue;}
    trade.PositionClose(ticket);
    if(trade.ResultRetcode() != TRADE_RETCODE_DONE){
    Print("Filed to clese position. ticket:",(string) ticket," result:",(string)trade.ResultRetcode(),
    ":",trade.CheckResultRetcodeDescription());
    }
    
    
   }
  }
 return true;
}
  
//+------------------------------------------------------------------+
