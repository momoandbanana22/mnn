PROGRAM_VERSION = 'ver.20180408_1900'.freeze
PROGRAM_NAME = 'mnn'.freeze

# standerd library require
require 'logger'

# relateve file
require_relative 'bbcc_api_access.rb'
require_relative 'mnn_log.rb'

# read setting.yaml filr
SETTING = YAML.load_file('setting.yaml')

# global log file
LOG = MnnLog.new(SETTING['log']['filepath'])
LOG.enable = SETTING['log']['enable']

# write info of prgram start.
LOG.info(object_id, 'main', 'main', (PROGRAM_NAME + ' ' + PROGRAM_VERSION))

# the 'mnn' , main class
class Mnn
  # constractor
  def initialize
    @bbcc_api = BbccAPIAccess.new
  end

  # read balance
  def read_balance
    @balance = @bbcc_api.read_balance
  end
end

# test code for API access
mnn = Mnn.new

loop do
  tmp = mnn.read_balance
  redo if tmp.nil?
  pp tmp
  break # exit loop
end
