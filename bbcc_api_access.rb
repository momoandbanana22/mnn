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
  end

  # random wait
  private def random_wait
    # wait in @randomwait_st[sec] - @randomwait_ed[sec]
    sleep(@randomwait_st + @random.rand(@randomwait_ed - @randomwait_st))
  end

  ##########
  # balance
  ##########

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

  public def read_balance
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
end
