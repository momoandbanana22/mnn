module StatusValues
  INITSTATUS        = 0
  GET_MYAMOUNT      = 1
  GET_PRICE         = 2
  CALC_BUYPRICE     = 3
  CALC_BUYAMOUNT    = 4
  ORDER_BUY         = 5
  WAIT_BUY          = 6
  CALC_SELLPRICE    = 7
  CALC_SELLAMOUNT   = 8
  ORDER_SELL        = 9
  WAIT_SELL         = 10
  CANCEL_BUYORDER   = 11
  CANCEL_SELLORDER  = 12
  DISP_PROFITS      = 13
end

# status class
class Status
  STATUS_NAMES = {
    StatusValues::INITSTATUS        => '初期状態',
#    StatusValues::GET_MYAMOUNT      => '残高取得中',
    StatusValues::GET_PRICE         => '現在価格取得',
    StatusValues::CALC_BUYPRICE     => '購入価格計算',
    StatusValues::CALC_BUYAMOUNT    => '購入数量計算',
    StatusValues::ORDER_BUY         => '発注(購入)',
    StatusValues::WAIT_BUY          => '購入約定待ち',
    StatusValues::CALC_SELLPRICE    => '販売価格計算',
    StatusValues::CALC_SELLAMOUNT   => '販売数量計算',
    StatusValues::ORDER_SELL        => '発注(販売)',
    StatusValues::WAIT_SELL         => '販売約定待ち',
    StatusValues::CANCEL_BUYORDER   => '購入注文中断',
    StatusValues::CANCEL_SELLORDER  => '販売注文中断',
    StatusValues::DISP_PROFITS      => '利益表示'
  }.freeze

  attr_accessor :current_status

  public def initialize
    @current_status = StatusValues::INITSTATUS
  end

  NEXT = {
#    StatusValues::INITSTATUS       => StatusValues::GET_MYAMOUNT,
#    StatusValues::GET_MYAMOUNT     => StatusValues::GET_PRICE,
    StatusValues::INITSTATUS       => StatusValues::GET_PRICE,
    StatusValues::GET_PRICE        => StatusValues::CALC_BUYPRICE,
    StatusValues::CALC_BUYPRICE    => StatusValues::CALC_BUYAMOUNT,
    StatusValues::CALC_BUYAMOUNT   => StatusValues::ORDER_BUY,
    StatusValues::ORDER_BUY        => StatusValues::WAIT_BUY,
    StatusValues::WAIT_BUY         => StatusValues::CALC_SELLPRICE,
    StatusValues::CALC_SELLPRICE   => StatusValues::CALC_SELLAMOUNT,
    StatusValues::CALC_SELLAMOUNT  => StatusValues::ORDER_SELL,
    StatusValues::ORDER_SELL       => StatusValues::WAIT_SELL,
    StatusValues::WAIT_SELL        => StatusValues::DISP_PROFITS,
#    StatusValues::DISP_PROFITS     => StatusValues::GET_MYAMOUNT,
    StatusValues::DISP_PROFITS     => StatusValues::GET_PRICE,
#    StatusValues::CANCEL_BUYORDER  => StatusValues::GET_MYAMOUNT,
    StatusValues::CANCEL_BUYORDER  => StatusValues::GET_PRICE,
    StatusValues::CANCEL_SELLORDER => StatusValues::CALC_SELLPRICE
  }.freeze

  public def next
    @current_status = NEXT[@current_status]
  end

  public def set(newstatus)
    @current_status = newstatus
  end

  public def to_s
    STATUS_NAMES[@current_status]
  end
end
