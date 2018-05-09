PROGRAM_VERSION = 'ver.20180509_2055'.freeze
PROGRAM_NAME = 'mnn'.freeze

# standerd library require
require 'logger'

# relateve file
require_relative 'bbcc_api_access.rb'
require_relative 'mnn_log.rb'

# read setting.yaml file
SETTING_YAML = 'setting.yaml'.freeze
setting = YAML.load_file(SETTING_YAML)

# global log file
LOG = MnnLog.new(setting['log']['filepath'])
LOG.enable = setting['log']['enable']

# write info of prgram start.
LOG.info(object_id, 'main', 'main', (PROGRAM_NAME + ' ' + PROGRAM_VERSION))

# the 'mnn' , main class
class Mnn
  # constractor
  public def initialize
    read_setting
    @bbcc = BbccAPIAccess.new(@random_start, @random_end)
  end

  # read setting.yaml
  public def read_setting
    # read setting.yaml file
    setting = YAML.load_file(SETTING_YAML)
    @random_start = setting['random']['start']
    @random_end = setting['random']['end']
  end

  public def start
    @bbcc.add_pair('btc_jpy')
    @bbcc.add_pair('xrp_jpy')

    ret = @bbcc.request_buy(object_id, 'btc_jpy', 0.0001, 800_000)
    ret = @bbcc.request_cancel_order(object_id, ret[:res])

    ret = @bbcc.request_read_balance(object_id)
    puts ret
    ret = @bbcc.request_get_price(object_id, 'btc_jpy')
    puts ret
    last_price = ret[:res]['last']
    loop do
      ret = @bbcc.request_buy(object_id, 'btc_jpy', 0.001, last_price)
      redo if ret == 20_001
      break
    end
    puts ret
    loop do
      is_contract = @bbcc.contract?(object_id, ret[:res])
      puts is_contract
      sleep(0.01)
      break if is_contract == true
    end
    ret = @bbcc.request_sell(object_id, 'btc_jpy', 0.001, last_price.to_f + 1_000)
    puts ret
    loop do
      is_contract = @bbcc.contract?(object_id, ret[:res])
      puts is_contract
      sleep(0.01)
      break if is_contract == true
    end
    loop do
      sleep(1)
    end
  end
end

# test code
mnn = Mnn.new
mnn.start
