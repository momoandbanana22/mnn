# standerd library require
require 'date'

# relateve file
require_relative 'status.rb'
require_relative 'trend.rb'
require_relative 'slack.rb'

# agent class
class Agent
  TOTAL_PROFITS_FILENAME = 'total_profits.yaml'.freeze
  @buy_amount_atonetime = 0
  @magnification = 1.0005

  private def read_maxorderwait(setting)
    @max_order_wait = { buy: 10, sell: 10 }
    @max_order_wait[:buy] = setting['buy'].to_i
    @max_order_wait[:sell] = setting['sell'].to_i
  end

  public def read_setting
    setting = YAML.load_file('setting_agents.yaml')
    read_maxorderwait(setting[@target_pair]['max_orderwait'])
    @buy_amount_atonetime = setting[@target_pair]['buy_amount_atonetime'].to_f
    @magnification = setting[@target_pair]['magnification'].to_f
  end

  public def initialize(target_pair)
    @target_pair = target_pair
    BBCC.add_pair(@target_pair)
    @current_status = Status.new
    @trend = Trend.new(target_pair) if @trend.nil?
    read_setting
  end

  attr_reader :target_pair

  private def do_initstatus
    @current_status.next
  end

  private def do_getmyamount
    @amount = BBCC.request_read_balance(object_id)
    @current_status.next
  end

  private def do_getprice
    @coin_price = BBCC.price_memory[@target_pair]
    @current_status.next
  end

  private def do_calcbuyprice
    @target_buy_price = (@coin_price['buy'].to_f + @coin_price['last'].to_f) / 2
    @current_status.next
  end

  private def do_calcbuyamount
    tukau = @buy_amount_atonetime.to_f
    coin = @target_pair.split('_')[1]
    freeamount = @amount[:res][coin]['free_amount'].to_f
    @target_buy_amount = tukau.to_f / @target_buy_price.to_f
    @target_buy_amount = freeamount if @target_buy_amount > freeamount
    @current_status.next
  end

  private def do_orderbuy
    @my_buy_order_info = BBCC.request_buy(object_id,
                                          @target_pair,
                                          @target_buy_amount,
                                          @target_buy_price)
    if numeric?(@my_buy_order_info[:res])
      # errir detect
      if @my_buy_order_info[:res] > 60_000
        @current_status.current_status = StatusValues::GET_PRICE
      end
    else
      @current_status.next
    end
  end

  private def do_waitorderbuy
    @current_status.next if BBCC.contract?(object_id, @my_buy_order_info[:res])
  end

  private def do_calcsellprice
    @coin_price = BBCC.price_memory[@target_pair]
    @target_sell_price = @target_buy_price.to_f * @magnification
    market_price = (@coin_price['sell'].to_f + @coin_price['last'].to_f) / 2
    market_price /= @magnification
    if @target_sell_price < market_price
      diff = market_price - @target_sell_price
      diff *= 0.9
      market_price = @target_sell_price + diff
      @target_sell_price = market_price
    end
    @current_status.next
  end

  private def do_calcsellamount
    @target_sell_amount = @target_buy_amount
    @current_status.next
  end

  private def do_ordersell
    @my_sell_order_info = BBCC.request_sell(object_id,
                                            @target_pair,
                                            @target_sell_amount,
                                            @target_sell_price)
    if numeric?(@my_sell_order_info[:res])
      # error detect. but cant rescure.
      sleep(0.1)
    else
      @current_status.next
    end
  end

  private def do_waitordersell
    @current_status.next if BBCC.contract?(object_id, @my_sell_order_info[:res])
  end

  private def read_total_profits
    YAML.load_file(TOTAL_PROFITS_FILENAME)
  rescue
    {}
  end

  private def add_profit(unite_name, profit)
    total_profits = read_total_profits
    if total_profits[unite_name].nil?
      total_profits['create_datetime'] = DateTime.now.to_s
      total_profits[unite_name] = profit
    else
      total_profits[unite_name] = total_profits[unite_name].to_f + profit
    end
    File.open(TOTAL_PROFITS_FILENAME, 'w') do |f|
      YAML.dump(total_profits, f)
    end
  end

  private def do_dispprofits
    print(DateTime.now)
    print(' ' + object_id.to_s)
    print(' ' + @target_pair)
    print(' ' + '利益表示')

    coin = @target_pair.split('_')[1].to_s

    sell = @my_sell_order_info[:res]['price'].to_f
    sell *= @my_sell_order_info[:res]['start_amount'].to_f

    buy = @my_buy_order_info[:res]['price'].to_f
    buy *= @my_buy_order_info[:res]['start_amount'].to_f

    current_profits = sell.to_f - buy.to_f

    add_profit(coin, current_profits)

    disp_str = "合計:#{read_total_profits[coin]} #{coin} 今回:#{current_profits}"
    print(' ' + disp_str + "\r\n")

    LOG.info(object_id, self.class.name, __method__, disp_str)
    MySlack.instance.post(disp_str)

    @current_status.next
  end

  private def do_cancelbuy
  end

  private def do_cancelsell
  end

  STATE_TABLE = {
    StatusValues::INITSTATUS        => Agent.instance_method(:do_initstatus),
    StatusValues::GET_MYAMOUNT      => Agent.instance_method(:do_getmyamount),
    StatusValues::GET_PRICE         => Agent.instance_method(:do_getprice),
    StatusValues::CALC_BUYPRICE     => Agent.instance_method(:do_calcbuyprice),
    StatusValues::CALC_BUYAMOUNT    => Agent.instance_method(:do_calcbuyamount),
    StatusValues::ORDER_BUY         => Agent.instance_method(:do_orderbuy),
    StatusValues::WAIT_BUY          => Agent.instance_method(:do_waitorderbuy),
    StatusValues::CALC_SELLPRICE    => Agent.instance_method(:do_calcsellprice),
    StatusValues::CALC_SELLAMOUNT   => Agent.instance_method(:do_calcsellamount),
    StatusValues::ORDER_SELL        => Agent.instance_method(:do_ordersell),
    StatusValues::WAIT_SELL         => Agent.instance_method(:do_waitordersell),
    StatusValues::DISP_PROFITS      => Agent.instance_method(:do_dispprofits),
    StatusValues::CANCEL_BUYORDER   => Agent.instance_method(:do_cancelbuy),
    StatusValues::CANCEL_SELLORDER  => Agent.instance_method(:do_cancelsell)
  }.freeze

  public def baiba
    @mythread = Thread.start do
      loop do
        func = STATE_TABLE[@current_status.current_status]
        func.bind(self).call
      end
    end
  end
end
