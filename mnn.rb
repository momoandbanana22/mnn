PROGRAM_VERSION = 'ver.20180430_1707'.freeze
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
    @random = Random.new
  end

  # read setting.yaml
  public def read_setting
    # read setting.yaml file
    setting = YAML.load_file(SETTING_YAML)
    @random_start = setting['random']['start']
    @random_end = setting['random']['end']
  end

  public def start
    @bbcc.read_balance
  end
end

# test code
mnn = Mnn.new
puts mnn.start
