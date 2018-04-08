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
  def initialize
    config_api_key = YAML.load_file('apikey.yaml')
    @bbcc = Bitbankcc.new(config_api_key['apikey'], config_api_key['seckey'])
  end

  # raw read balance without retry
  def raw_read_balance
    JSON.parse(@bbcc.read_balance)
  rescue StandardError => exception
    LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
    nil # retruen(nil)
  end

  # read balance
  def read_balance
    return nil if (res = raw_read_balance).nil?
    return nil unless res['success'] == 1

    # save balance to hash (usage: barance['jpy']['free_amount'])
    balance = Hash.new { |h, k| h[k] = {} }

    # convert res to balance hash
    res['data']['assets'].each do |one_asset|
      currency_name = one_asset['asset']
      one_asset.each do |key, val|
        balance[currency_name][key] = val unless key == 'asset'
      end
    end

    # retrun my barance
    balance # retrun(balance)
  end
end
