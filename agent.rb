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
    @to_stop = false
    @stopped = false
    @lasterrorcode = 0
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
    return if @coin_price.nil?
    @current_status.next
  end

  private def do_calcbuyprice
    @target_buy_price = (@coin_price['buy'].to_f + @coin_price['last'].to_f) / 2
    @current_status.next
  end

  private def do_calcbuyamount
    tukau = @buy_amount_atonetime.to_f
    # coin = @target_pair.split('_')[1]
    # freeamount = @amount[:res][coin]['free_amount'].to_f
    @target_buy_amount = tukau.to_f / @target_buy_price.to_f
    # @target_buy_amount = freeamount if @target_buy_amount > freeamount
    @current_status.next
  end

  private def do_orderbuy
    if @to_stop && !@stopped
      @stopped = true
      disp = "#{DateTime.now} #{object_id} #{target_pair} buy stop."
      puts(disp)
    end
    return if @stopped
    @my_buy_order_info = BBCC.request_buy(object_id,
                                          @target_pair,
                                          @target_buy_amount,
                                          @target_buy_price)
    disp = "#{DateTime.now} #{object_id} #{target_pair}"
    res = @my_buy_order_info[:res]
    if numeric?(res)
      # errir detect
      if @lasterrorcode != res
        @lasterrorcode = res
        disp += " err:#{res} buy_order"
        puts(disp)
      end
      @current_status.set(StatusValues::GET_PRICE) if res > 60_000
    else
      @order_count = 0
      @lasterrorcode = 0
      disp += " OK 数量:#{res['start_amount']} 金額:#{res['price']} buy_order"
      puts(disp)
      @current_status.next
    end
  end

  private def do_waitorderbuy
    contracted = BBCC.contract?(object_id, @my_buy_order_info[:res])
    if contracted
      @current_status.next
      return
    end
    # not contracted
    if @order_count > @max_order_wait[:buy]
      # retry out
      @current_status.set(StatusValues::CANCEL_BUYORDER)
      disp = "#{DateTime.now} #{object_id} #{target_pair} orderbuy retryout."
      puts(disp)
      return
    end
    @order_count += 1
  end

  private def do_calcsellprice
    @coin_price = BBCC.price_memory[@target_pair]
    @target_sell_price = @target_buy_price.to_f * @magnification
    market_price = (@coin_price['sell'].to_f + @coin_price['last'].to_f) / 2
    # market_price /= @magnification
    if @target_sell_price < market_price
      # @target_sell_price += (market_price - @target_sell_price) * 0.9
      disp = "#{DateTime.now} #{object_id} #{target_pair} calc_sell_price "
      disp += "#{@target_sell_price}->#{market_price}"
      disp += "[#{(market_price - @target_sell_price)}]"
      puts(disp)
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
    disp = "#{DateTime.now} #{object_id} #{target_pair}"
    res = @my_sell_order_info[:res]
    if numeric?(res)
      # error detect. but cant rescure.
      if @lasterrordere != res
        @lasterrorcode = res
        disp += " err:#{res} sellorder"
      end
    else
      @order_count = 0
      @lasterrorcode = 0
      disp += " OK 数量:#{res['start_amount']} 金額:#{res['price']} sellorder"
      @current_status.next
    end
    puts(disp)
  end

  private def do_waitordersell
    if @to_stop && !@stopped
      @stopped = true
      disp = "#{DateTime.now} #{object_id} #{target_pair} sell stop."
      puts(disp)
    end
    return if @stopped
    contracted = BBCC.contract?(object_id, @my_sell_order_info[:res])
    if contracted
      @current_status.next
      return
    end
    # not contracted
    if @order_count > @max_order_wait[:sell]
      # retry out
      @current_status.set(StatusValues::CANCEL_SELLORDER)
      disp = "#{DateTime.now} #{object_id} #{target_pair} ordersell retyuout."
      puts(disp)
      return
    end
    @order_count += 1
  end

  private def read_total_profits
    YAML.load_file(TOTAL_PROFITS_FILENAME)
  rescue
    {} # return empty hash
  end

  private def add_profit(unite_name, profit)
    moto = 0
    total_profits = read_total_profits
    if total_profits[unite_name].nil?
      total_profits['create_datetime'] = DateTime.now.to_s
    else
      moto = total_profits[unite_name].to_f
    end
    total_profits[unite_name] = moto + profit
    File.open(TOTAL_PROFITS_FILENAME, 'w') { |f| YAML.dump(total_profits, f) }
    total_profits[unite_name] # return ret
  end

  private def do_dispprofits
    disp1 = "#{DateTime.now} #{object_id} #{@target_pair} 利益表示 "

    coin = @target_pair.split('_')[1].to_s

    sellres = @my_sell_order_info[:res]
    sell = sellres['price'].to_f * sellres['start_amount'].to_f

    buyres = @my_buy_order_info[:res]
    buy = buyres['price'].to_f * buyres['start_amount'].to_f

    current_profits = sell.to_f - buy.to_f

    total = add_profit(coin, current_profits)

    disp2 = "合計:#{total} #{coin} 今回:#{current_profits}"
    print(disp1 + disp2 + "\r\n")

    LOG.info(object_id, self.class.name, __method__, disp2)
    MySlack.instance.post(disp2)

    @current_status.next
  end

  private def do_cancelbuy
    cancelled = BBCC.request_cancel_order(object_id, @my_buy_order_info[:res])
    @current_status.next if cancelled
  end

  private def do_cancelsell
    cancelled = BBCC.request_cancel_order(object_id, @my_sell_order_info[:res])
    @current_status.next if cancelled
  end

  STATE_TABLE = {
    StatusValues::INITSTATUS        => Agent.instance_method(:do_initstatus),
#    StatusValues::GET_MYAMOUNT      => Agent.instance_method(:do_getmyamount),
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

  public def baibai
    @mythread = Thread.start do
      loop do
        sleep(0.0001) # 100uS
        if @to_stop && !@stopped
          disp = "#{DateTime.now} #{object_id} #{@target_pair} stopping..."
          puts(disp)
        end
        func = STATE_TABLE[@current_status.current_status]
        func.bind(self).call
      end
    end
  end

  public def to_stop
    @to_stop = true
  end

  public def stopped?
    @stopped
  end
end
