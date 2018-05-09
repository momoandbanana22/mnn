# access to BitBankAPI useing https://github.com/bitbankinc/ruby_bitbankcc

# standerd library require
require 'yaml'

# gem require
require 'ruby_bitbankcc'

# relateve file
require_relative 'bbcc_info.rb'
require_relative 'que.rb'

# bitbank api acces class
class BbccAPIAccess
  # values for get_price target_pair
  attr_accessor :target_pairs
  attr_accessor :price_memory

  # constractor
  public def initialize(randomwait_st, randomwait_ed)
    config_api_key = YAML.load_file('apikey.yaml')
    @bbcc = Bitbankcc.new(config_api_key['apikey'], config_api_key['seckey'])
    @randomwait_st = randomwait_st
    @randomwait_ed = randomwait_ed
    @random = Random.new
    @target_pairs = []
    @price_memory = {}
    init_que
    thread_start
  end

  private def init_que
    @req_que = Que.new
    @res_que = ResQue.new
  end

  private def do_method(req)
    case req[:method]
    when READ_BALANCE then
      read_balance
    when ORDER then
      create_order(req[:orderinfo])
    when READ_ACTIVE_ORDERS then
      read_active_orders(req[:target_pair])
    when GET_PRICE then
      get_price(req[:target_pair])
    when CANCEL_ORDER then
      cancel_order(req[:target_pair], req[:order_id])
    else
      exit(-1)
    end
  end

  # add pair for get_price
  public def add_pair(pair)
    @target_pairs.push(pair)
  end

  # get next pair for get_price/memory_price
  private def next_pair_for_memory_price
    return(nil) if @target_pairs.nil?
    @target_pair_idx = 0 if @target_pair_idx.nil?
    @target_pair_idx = 0 if @target_pairs.size <= @target_pair_idx
    ret = @target_pairs[@target_pair_idx]
    @target_pair_idx += 1
    ret # return(ret)
  end

  private def memory_price(pair)
    return if pair.nil?
    @price_memory[pair] = get_price(pair)
  end

  private def set_res(req, res)
    tmphash = { res_time: Time.now.to_f, req_time: req[:req_time],
                objid: req[:objid], res: res }
    @res_que.push(tmphash)
    @req_que.shift
  end

  private def thread_start
    @mythread = Thread.start do
      loop do
        # do get_price and memory it
        memory_price(next_pair_for_memory_price)

        # search request
        req = @req_que.peek
        redo if req.nil?

        # found reques, do method
        res = do_method(req)

        # add responce, del req_que
        set_res(req, res)
      end
    end
  end

  private def random_wait
    # wait in @randomwait_st[sec] - @randomwait_ed[sec]
    sleep(@randomwait_st + @random.rand(@randomwait_ed - @randomwait_st))
  end

  private def add_request(request_hash)
    @req_que.push(request_hash)
  end

  private def take_res(objid)
    @res_que.take_res(objid)
  end

  private def numeric?(value)
    return(true) if value.is_a?(Numeric)
    return(true) if Integer(value)
    return(true) if Float(value)
    false # return false
  rescue StandardError
    false # return false
  end

  ##########
  # balance
  ##########

  READ_BALANCE = 'read_balance'.freeze

  private def api_read_balance
    JSON.parse(@bbcc.read_balance)
  rescue StandardError => exception
    LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
    nil # return nil
  end

  private def retry_read_balance
    res = nil
    loop do
      res = api_read_balance
      return res unless res.nil?
      random_wait
    end
  end

  private def http_read_balance
    res = retry_read_balance
    return(res) if res['success'] == 1
    erstr = "bbcc.read_balance() not success. code=#{res['data']['code']}"
    LOG.error(object_id, self.class.name, __method__, erstr)
    res['data']['code'].to_i # return res['data']['code'].to_i
  end

  private def read_balance
    ret = Hash.new { |h, k| h[k] = {} }
    res = http_read_balance
    return(res) if numeric?(res)
    res['data']['assets'].each do |one_asset|
      one_asset.each do |key, val|
        (ret[one_asset['asset']][key] = val) if key != 'asset'
      end
    end
    ret # return ret
  end

  public def request_read_balance(objid)
    tmphash = { req_time: Time.now.to_f, objid: objid,
                method: READ_BALANCE }
    add_request(tmphash)
    take_res(objid)
  end

  ########
  # order
  ########

  ORDER = 'order'.freeze

  private def api_create_order(orderinfo)
    JSON.parse(@bbcc.create_order(orderinfo[:target_pair], orderinfo[:amount],
                                  orderinfo[:price], orderinfo[:side],
                                  orderinfo[:type]))
  rescue StandardError => exception
    LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
    nil # return nil
  end

  private def retry_create_order(orderinfo)
    res = nil
    loop do
      res = api_create_order(orderinfo)
      return res unless res.nil?
      random_wait
    end
  end

  private def http_create_order(orderinfo)
    res = retry_create_order(orderinfo)
    return(res) if res['success'] == 1
    erstr = "bbcc.create_order() not success. code=#{res['data']['code']}"
    LOG.error(object_id, self.class.name, __method__, erstr)
    res['data']['code'].to_i # return res['data']['code'].to_i
  end

  private def create_order(orderinfo)
    ret = {}
    res = http_create_order(orderinfo)
    return(res) if numeric?(res)
    res['data'].each do |key, val|
      (ret[key] = val) if key != 'success'
    end
    ret # return ret
  end

  public def request_buy(objid, target_pair, amount, price)
    orderinfo = { target_pair: target_pair, amount: amount, price: price,
                  side: 'buy', type: 'limit' }
    tmphash = { req_time: Time.now.to_f, objid: objid,
                method: ORDER, orderinfo: orderinfo }
    add_request(tmphash)
    take_res(objid)
  end

  #####################
  # read active orders
  #####################

  READ_ACTIVE_ORDERS = 'read_active_orders'.freeze

  private def api_read_active_orders(target_pair)
    JSON.parse(@bbcc.read_active_orders(target_pair))
  rescue StandardError => exception
    LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
    nil # return nil
  end

  private def retry_read_active_orders(target_pair)
    res = nil
    loop do
      res = api_read_active_orders(target_pair)
      return res unless res.nil?
      random_wait
    end
  end

  private def http_read_active_orders(target_pair)
    res = retry_read_active_orders(target_pair)
    return res if res['success'] == 1
    erstr = "bbcc.read_active_orders() not success. code=#{res['data']['code']}"
    LOG.error(object_id, self.class.name, __method__, erstr)
    res['data']['code'].to_i # return res['data']['code'].to_i
  end

  private def read_active_orders(target_pair)
    ret = {}
    res = http_read_active_orders(target_pair)
    return(res) if numeric?(res)
    res['data'].each do |key, val|
      (ret[key] = val) if key != 'success'
    end
    ret # return ret
  end

  public def request_read_active_orders(objid, orderd_info)
    tmphash = { req_time: Time.now.to_f, objid: objid,
                method: READ_ACTIVE_ORDERS,
                target_pair: orderd_info['pair'] }
    add_request(tmphash)
    take_res(objid)
  end

  public def contract?(objid, orderd_info)
    ret = request_read_active_orders(objid, orderd_info)
    return(false) if numeric?(ret[:res])
    ret[:res]['orders'].each do |one_order|
      next unless one_order['order_id'] == orderd_info['order_id']
      next unless one_order['pair'] == orderd_info['pair']
      return(true) if one_order['status'] == 'FULLY_FILLED'
      return(false) # if one_order['status'] == 'PARTIALLY_FILLED'
    end
    true # retur true # not found = not active order
  end

  public def wait_contruct(objid, orderd_info)
    loop do
      return if contract?(objid, orderd_info)
    end
  end

  ############
  # get_price
  ############

  GET_PRICE = 'get_price'.freeze

  private def api_get_price(target_pair)
    JSON.parse(@bbcc.read_ticker(target_pair))
  rescue StandardError => exception
    LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
    nil # return nil
  end

  private def retry_get_price(target_pair)
    res = nil
    loop do
      res = api_get_price(target_pair)
      return res unless res.nil?
      random_wait
    end
  end

  private def http_get_price(target_pair)
    res = retry_get_price(target_pair)
    return(res) if res['success'] == 1
    erstr = "bbcc.read_ticker() not success. code=#{res['data']['code']}"
    LOG.error(object_id, self.class.name, __method__, erstr)
    res['data']['code'].to_i # return res['data']['code'].to_i
  end

  private def get_price(target_pair)
    ret = {}
    res = http_get_price(target_pair)
    return(res) if numeric?(res)
    res['data'].each do |key, val|
      (ret[key] = val) if key != 'success'
    end
    ret # return ret
  end

  public def request_get_price(objid, target_pair)
    tmphash = { req_time: Time.now.to_f, objid: objid,
                method: GET_PRICE,
                target_pair: target_pair }
    add_request(tmphash)
    take_res(objid)
  end

  public def request_sell(objid, target_pair, amount, price)
    orderinfo = { target_pair: target_pair, amount: amount, price: price,
                  side: 'sell', type: 'limit' }
    tmphash = { req_time: Time.now.to_f, objid: objid,
                method: ORDER, orderinfo: orderinfo }
    add_request(tmphash)
    take_res(objid)
  end

  ###############
  # cancel order
  ###############

  CANCEL_ORDER = 'cancel_order'.freeze

  private def api_cancel_order(target_pair, order_id)
    JSON.parse(@bbcc.cancel_order(target_pair, order_id))
  rescue StandardError => exception
    LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
    nil # return nil
  end

  private def retry_cancel_order(target_pair, order_id)
    res = nil
    loop do
      res = api_cancel_order(target_pair, order_id)
      return res unless res.nil?
      random_wait
    end
  end

  private def http_cancel_order(target_pair, order_id)
    res = retry_cancel_order(target_pair, order_id)
    return(res) if res['success'] == 1
    erstr = "bbcc.cancel_order() not success. code=#{res['data']['code']}"
    LOG.error(object_id, self.class.name, __method__, erstr)
    res['data']['code'].to_i # return res['data']['code'].to_i
  end

  private def cancel_order(target_pair, order_id)
    res = http_cancel_order(target_pair, order_id)
    return(false) if numeric?(res)
    true # return(true)
  end

  public def request_cancel_order(objid, orderd_info)
    tmphash = { req_time: Time.now.to_f, objid: objid, method: CANCEL_ORDER,
                target_pair: orderd_info['pair'],
                order_id: orderd_info['order_id'] }
    add_request(tmphash)
    take_res(objid)
  end
end
