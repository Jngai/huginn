module Agents
  class DropboxAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      The DropboxAgent lets you upload files to your Dropbox account.
      It requires a [Dropbox app](https://www.dropbox.com/developers/apps) and its `access_token`, which will be used to authenticate on your account.

      At the moment it only supports another URL as the source.
    MD

    def default_options
      {
        access_token: 'your_dropbox_app_access_token',
        source_url: 'http://download.thinkbroadband.com/5MB.zip'
      }
    end

    def validate_options
      errors.add(:base, 'The `access_token` property is required.') unless options['access_token'].present?
      errors.add(:base, 'The `source_url` property is required.') unless options['source_url'].present?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each { |event| send_to_dropbox interpolated(event) }
    end

    def send_to_dropbox(interpolated_event)
      source_url = interpolated_event[:source_url]
      dropbox = DropboxStream.new(interpolated[:access_token])

      log("Streaming '#{source_url}' to Dropbox.")
      request = HTTParty::Request.new(Net::HTTP::Get, source_url)
      request.perform { |chunk| dropbox.send(chunk) }
      dropbox.done(URI.parse(source_url).path)
    end
  end
end

# TODO: Move this out of spike mode and cover with tests. Improve error handling
class DropboxStream
  include HTTParty
  base_uri 'https://api-content.dropbox.com/1'
  headers 'Content-Type' => 'application/x-www-form-urlencoded; charset=utf-8'

  def initialize(access_token)
    @options = { query: { access_token: access_token } }
  end

  def send(chunk)
    raise Error('Stream closed.') if @closed
    options = @options.merge({ body: chunk })
    options[:query][:upload_id] = @upload_id if @upload_id
    options[:query][:offset] = @offset if @offset

    response = self.class.put('/chunked_upload', options)
    response = JSON.parse response
    @upload_id = response['upload_id']
    @offset = response['offset']
    log "Chunk sent: #{@upload_id} | #{@offset}"
  end

  def done(path)
    raise Error('Not uploaded.') unless @upload_id
    options = @options.deep_merge({ query: { upload_id: @upload_id, overwrite: false } })
    response = self.class.post("/commit_chunked_upload/auto#{path}", options)
    log('Upload finished.')
    @closed = true
  end
end
