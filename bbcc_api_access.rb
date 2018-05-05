# access to BitBankAPI useing https://github.com/bitbankinc/ruby_bitbankcc

# standerd library require
require 'yaml'

# gem require
require 'ruby_bitbankcc'

# relateve file
require_relative 'bbcc_info.rb'

# Que class
class Que
  public def initialize
    @lock = Mutex.new
    @que = [] # empty array
  end
  # take top item
  public def peek
    loop do
      redo if @que.empty?
      @lock.synchronize do
        return @que[0]
      end
    end
  end
  # add item
  public def push(item)
    @lock.synchronize do
      @que.push(item)
    end
  end
  # del item
  public def shift
    @lock.synchronize do
      @que.shift
    end
  end
end

# ResQue class
class ResQue < Que
  public def take_res(objid)
    loop do
      ret = nil
      @lock.synchronize { ret = @que.select { |res| res[:objid] == objid } }
      redo if ret.empty?
      @lock.synchronize { @que.reject! { |res| res[:objid] == objid } }
      return ret # return ret
    end
  end
end

# bitbank api acces class
class BbccAPIAccess
  # constractor
  public def initialize(randomwait_st, randomwait_ed)
    config_api_key = YAML.load_file('apikey.yaml')
    @bbcc = Bitbankcc.new(config_api_key['apikey'], config_api_key['seckey'])
    @randomwait_st = randomwait_st
    @randomwait_ed = randomwait_ed
    init_que
    thread_start
  end

  private def init_que
    @req_que = Que.new
    @res_que = ResQue.new
  end

  private def do_method(req)
    res = nil
    case req[:method]
    when READ_BALANCE then
      res = read_balance
    when ORDER then
      res = create_order(req[:orderinfo])
    else
      exit(-1)
    end
    res # return res
  end

  private def thread_start
    @mythread = Thread.start do
      loop do
        # search request
        tmp_req = @req_que.peek

        # found reques, do method
        res = do_method(tmp_req)

        # add responce, del req_que
        tmphash = { res_time: Time.now.to_f, req_time: tmp_req[:req_time],
                    objid: tmp_req[:objid], res: res }
        @res_que.push(tmphash)
        @req_que.shift
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
    return true if value.is_a?(Numeric)
    return true if Integer(value)
    return true if Float(value)
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
      break unless res.nil?
      random_sleep
    end
    res # return res
  end

  private def http_read_balance
    res = retry_read_balance
    if res['success'] != 1
      errstr = "bbcc.read_balance() not success. code=#{res['data']['code']}"
      LOG.error(object_id, self.class.name, __method__, errstr)
      return res['data']['code'].to_i
    end
    res # return res
  end

  private def read_balance
    ret = Hash.new { |h, k| h[k] = {} }
    res = http_read_balance
    return res if numeric?(res)
    res['data']['assets'].each do |one_asset|
      one_asset.each do |key, val|
        ret[one_asset['asset']][key] = val if key != 'asset'
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
      break unless res.nil?
      random_sleep
    end
    res # return res
  end

  private def http_create_order(orderinfo)
    res = retry_create_order(orderinfo)
    if res['success'] != 1
      errstr = "bbcc.create_order() not success. code=#{res['data']['code']}"
      LOG.error(object_id, self.class.name, __method__, errstr)
      return res['data']['code'].to_i
    end
    res # return res
  end

  private def create_order(orderinfo)
    ret = {}
    res = http_create_order(orderinfo)
    return res if numeric?(res)
    res['data'].each do |key, val|
      ret[key] = val if key != 'success'
    end
    ret # return ret
  end

  public def request_buy(objid, target_pair, amount, price)
    orderinfo = { target_pair: target_pair, amount: amount, pirce: price,
                  side: 'buy', type: 'limit' }
    tmphash = { req_time: Time.now.to_f, objid: objid,
                method: ORDER, orderinfo: orderinfo }
    add_request(tmphash)
    take_res(objid)
  end
end
