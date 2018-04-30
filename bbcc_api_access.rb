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

  private def do_method(method)
    res = nil
    case method
    when READ_BALANCE then
      res = read_balance
    else
      exit(-1)
    end
    res # return res
  end

  private def thread_start
    @mythread = Thread.start do
      loop do
        # search request
        tmp_req_que = @req_que.peek

        # found reques, do method
        res = do_method(tmp_req_que[:method])

        # add responce, del req_que
        tmphash = { objid: tmp_req_que[:objid], res: res }
        @res_que.push(tmphash)
        @req_que.shift
      end
    end
  end

  # random wait
  private def random_wait
    # wait in @randomwait_st[sec] - @randomwait_ed[sec]
    sleep(@randomwait_st + @random.rand(@randomwait_ed - @randomwait_st))
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
      return nil
    end
    res # return res
  end

  private def read_balance
    ret = Hash.new { |h, k| h[k] = {} }
    res = http_read_balance
    return ret if res.nil?
    res['data']['assets'].each do |one_asset|
      one_asset.each do |key, val|
        ret[one_asset['asset']][key] = val if key != 'asset'
      end
    end
    ret # return ret
  end

  private def add_request(request_hash)
    @req_que.push(request_hash)
  end

  private def take_res(objid)
    @res_que.take_res(objid)
  end

  # add resuest to que
  public def request_read_balance(objid)
    tmphash = { objid: objid, method: READ_BALANCE }
    add_request(tmphash)
    take_res(objid)
  end
end
