module Agents
  class DropboxAgent < Agent
    include DropboxConcern

    cannot_be_scheduled!

    description <<-MD
      The DropboxAgent lets you upload files to your Dropbox account.

      At the moment it only supports another URL as the source.
    MD

    def default_options
      {
        source_url: 'http://download.thinkbroadband.com/5MB.zip'
      }
    end

    def validate_options
      errors.add(:base, 'The `source_url` property is required.') unless options['source_url'].present?
    end

    def working?
      received_event_without_error? && !recent_error_logs? #need to refined at the end
    end

    def receive(incoming_events)
      events.each do |event|
        # download event.payload['url'] to a tmp file
        # load in chunks
        # loop and upload each chunk in-band, right here.
        # mix this with delayed job.
      end
    end

    def dropbox_request(interpolated_event)
      source_url = interpolated_event[:source_url]
      stream = DropboxStream.new()

      log("Streaming '#{source_url}' to Dropbox.")
      request = HTTParty::Request.new(Net::HTTP::Get, source_url)
      request.perform { |chunk| stream.send(chunk) }
      stream.done(URI.parse(source_url).path)
    end
  end
end

# TODO: Move this out of spike mode and cover with tests. Improve error handling
class DropboxStream
  include HTTParty
  base_uri 'https://api-content.dropbox.com/1'
  headers 'Content-Type' => 'application/x-www-form-urlencoded; charset=utf-8'

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
