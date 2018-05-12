require 'singleton'
require 'slack/incoming/webhooks'

# slack class
class MySlack
  include Singleton

  def initialize
    @lock = Mutex.new
    setting = YAML.load_file('slackSetting.yaml')
    @enable = setting['slack']['use']
    @slack = Slack::Incoming::Webhooks.new setting['slack']['webhookURL']
  rescue
    @enable = false
  end

  def post(msg)
    return unless @enable
    @lock.synchronize do
      @slack.post msg
    end
  rescue StandardError => exception
    LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
  end
end
