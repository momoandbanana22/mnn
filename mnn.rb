PROGRAM_VERSION = 'ver.20180512_1610'.freeze
PROGRAM_NAME = 'mnn'.freeze

# standerd library require
require 'logger'

# relateve file
require_relative 'bbcc_api_access.rb'
require_relative 'mnn_log.rb'
require_relative 'agent.rb'

public def numeric?(value)
  return(true) if value.is_a?(Numeric)
  return(true) if Integer(value)
  return(true) if Float(value)
  false # return false
rescue StandardError
  false # return false
end

# read setting.yaml file
SETTING_YAML = 'setting.yaml'.freeze
setting = YAML.load_file(SETTING_YAML)

# global log file
LOG = MnnLog.new(setting['log']['filepath'])
LOG.enable = setting['log']['enable']

# write info of prgram start.
LOG.info(object_id, 'main', 'main', (PROGRAM_NAME + ' ' + PROGRAM_VERSION))
MySlack.instance.post(PROGRAM_NAME + ' ' + PROGRAM_VERSION)

BBCC = BbccAPIAccess.new(setting['random']['start'], setting['random']['end'])

# the 'mnn' , main class
class Mnn
  public def start
    agent = Agent.new('btc_jpy')
    agent.baiba
  end
end

# test code
mnn = Mnn.new
mnn.start

loop do
  sleep(1)
end
