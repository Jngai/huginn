require 'spec_helper'

describe Agents::DropboxAgent do
  before(:each) do
    @agent = Agents::DropboxAgent.new(
      name: 'save to dropbox',
      options: {
        access_token: '70k3n',
        source_url: 'http://example.com/file.tgz'
      }
    )
    @agent.user = users(:bob)
  end

  it 'cannot be scheduled' do
    @agent.cannot_be_scheduled?.should == true
  end

  it 'has a description' do
    @agent.description.should_not be_nil
  end

  describe '#valid?' do
    before { @agent.should be_valid }

    it 'requires the "access_token"' do
      @agent.options[:access_token] = nil
      @agent.should_not be_valid
    end

    it 'requires a "source_url"' do
      @agent.options[:source_url] = nil
      @agent.should_not be_valid
    end
  end

  describe '#working?' do
    it 'relies on received_event_without_error?' do
      mock(@agent).received_event_without_error?
      @agent.working?
    end
  end

  # describe '#receive' do
  #   before do
  #     stub_request(:get, 'http://example.com/file.tgz')
  #   end
  # end
end
