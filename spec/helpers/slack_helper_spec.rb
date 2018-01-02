require "rails_helper"

RSpec.describe SlackHelper, type: :helper do
  describe "#slack_notify_list" do
    before do
      ENV["SLACK_TOKEN"] = "token"
      Rails.cache.clear
      stub_request(:post, "https://slack.com/api/users.list").
         to_return(status: 200, body: '{"members":[{"name":"release"},{"name":"hub"}]}', headers: {})

      stub_request(:post, "https://slack.com/api/channels.list").
        to_return(:status => 200, :body => '{"channels":[{"name":"release"},{"name":"hub"}]}')
    end

    it "pulls members and channels from api" do
      expect(helper.slack_notify_list).to eq('[{"name":"@release"},{"name":"@hub"},{"name":"#release"},{"name":"#hub"}]')
    end
  end
end
