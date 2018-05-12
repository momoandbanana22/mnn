# price trend class
class Trend
  public def initialize(pair)
    @pair = pair
    @price_history = []
    @delta = 0
    @old_price = 0
  end

  private def cmp3
    d1 = @price_history[1]['last'].to_f - @price_history[0]['last'].to_f
    d2 = @price_history[2]['last'].to_f - @price_history[1]['last'].to_f
    if d2 <= 0 # ↑ー
      @delta = 0
    elsif d1 > 0 && d2 > 0 # ↑↑
      @delta = d1 + d2
    elsif d1 < 0 && d2 > 0 # ↑↓
      @delta = d1 + d2
    end
    @price_history.shift # del [0]
  end

  private def cmp
    if @price_history.size == 1
      @delta = 0
    elsif @price_history.size == 2
      @delta = 0
    else
      # @price_history.size==3
      cmp3
    end
  end

  public def add_price_info(coin_price_info)
    new_price = coin_price_info['last'].to_f
    if @old_price == new_price
      @delta = 0
      return @delta
    end
    @price_history.push(coin_price_info)
    @old_price = new_price
    cmp
    @delta # return @delta
  end

  def trend
    @delta
  end

  def last_price
    @price_history.last
  end
end
