# access to BitBankAPI useing https://github.com/bitbankinc/ruby_bitbankcc

# standerd library require
require 'yaml'

# gem require
require 'ruby_bitbankcc'

# relateve file
require_relative 'bbcc_info.rb'

# bitbank api acces class
class BbccAPIAccess
  # constractor
  public def initialize(randomwait_st, randomwait_ed)
    config_api_key = YAML.load_file('apikey.yaml')
    @bbcc = Bitbankcc.new(config_api_key['apikey'], config_api_key['seckey'])
    @randomwait_st = randomwait_st
    @randomwait_ed = randomwait_ed
    @req_lock = Mutex.new
    @res_lock = Mutex.new
    @res_idlock = Mutex.new
    @req_que = [] # empty array
    @res_que = [] # empty arra
    @res_id = [] # empty arra
    thread_start
  end

  private def thread_start
    @mythread = Thread.start do
      loop do
        # search request
        tmp_req_que = nil
        @req_lock.synchronize do
          tmp_req_que = @req_que[0] unless @req_que.empty?
        end
        redo if tmp_req_que.nil?

        # found reques, do method
        res = nil
        case tmp_req_que[:method]
        when READ_BALANCE then
          res = read_balance
        else
          exit(-1)
        end

        # add responce, del res_que
        tmphash = { objid: tmp_req_que[:objid], res: res }
        @res_lock.synchronize do
          @res_que.push(tmphash)
        end
        @res_idlock.synchronize do
          @res_id.push(tmp_req_que[:objid])
        end
        @req_lock.synchronize do
          @req_que.shift
        end
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
    @req_lock.synchronize do
      @req_que.push(request_hash)
    end
  end

  private def wait_method(objid)
    loop do
      redo unless @res_id.include?(objid)
      @res_idlock.synchronize do
        @res_id.delete(objid)
      end
      idx = 0
      ret_res = nil
      @res_lock.synchronize do
        @res_que.each do |one_res|
          if one_res[:objid] == objid
            ret_res = one_res
            break
          end
          idx += 1
        end
        @res_que.delete_at(idx)
      end
      return ret_res
    end
  end

  # add resuest to que
  public def request_read_balance(objid)
    tmphash = { objid: objid, method: READ_BALANCE }
    add_request(tmphash)
    wait_method(objid)
  end
end
