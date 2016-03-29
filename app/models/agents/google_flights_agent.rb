module Agents
  class GoogleFlightsAgent < Agent
    include FormConfigurable

    cannot_receive_events!
    default_schedule "every_12h"


    description <<-MD
      The GoogleFlightsAgent will tell you the minimum airline prices between a pair of cities. The api limit is 50 requests/day.

      Follow their documentation here (https://developers.google.com/qpx-express/v1/prereqs#get-a-google-account) to retrieve an api key.
      After you get to the google developer console, created a project, enabled qpx express api then you can choose `api key` credential to be created.

      The `origin` and `destination` options require an [airport code](http://www.expedia.com/daily/airports/AirportCodes.asp).

      All the default options must exist. For `infantInSeatCount`, `infantInLapCount`, `seniorCount`, and `childCount`, leave them to the default value of `0` if its not necessary.

      Make sure `date` is in this type of date format `YYYY-MO-DAY`.

      You can limit the number of `solutions` returned back. The first solution is the lowest priced ticket.
    MD

    event_description <<-MD
      The event payload will have objects that contains valuable data like this

          "carrier": [
            { 
              "code": "B6",
              "name": "Jetblue Airways Corporation"
            }
          ]

          "tripOption": [ 
            "saleTotal": "USD49.10"
            "slice": [
            ... 
            ...
             "flight": {
                "carrier": "B6",
                "number": "833"
             }
            ]
          ]

    MD

    def default_options
      {
        'qpx_api_key' => '',
        'adultCount'=> 1,
        'origin' => 'BOS',
        'destination' => 'SFO',
        'date' => '2016-04-11',
        'childCount' => 0,
        'infantInSeatCount' => 0,
        'infantInLapCount'=> 0,
        'seniorCount'=> 0,
        'solutions'=> 3
      }
    end

    form_configurable :qpx_api_key, type: :string
    form_configurable :adultCount
    form_configurable :origin, type: :string
    form_configurable :destination, type: :string
    form_configurable :date, type: :string
    form_configurable :childCount
    form_configurable :infantInSeatCount
    form_configurable :infantInLapCount
    form_configurable :seniorCount
    form_configurable :solutions

    def validate_options
      errors.add(:base, "You need a qpx api key") unless options['qpx_api_key'].present?
      errors.add(:base, "Adult Count must exist") unless options['adultCount'].present?
      errors.add(:base, "Origin must exist") unless options['origin'].present?
      errors.add(:base, "Destination must exist") unless options['destination'].present?
      errors.add(:base, "Date must exist") unless options['date'].present?
      errors.add(:base, "Child Count") unless options['childCount'].present?
      errors.add(:base, "Infant In Seat Count must exist") unless options['infantInSeatCount'].present?
      errors.add(:base, "Infant In Lap Count") unless options['infantInLapCount'].present?
      errors.add(:base, "Senior Count must exist") unless options['seniorCount'].present?
      errors.add(:base, "Solutions must exist") unless options['solutions'].present?
    end

    def working?
      !recent_error_logs?
    end

    def check
      post_params = {:request=>{:passengers=>{:kind=>"qpxexpress#passengerCounts", :adultCount=> interpolated["adultCount"], :childCount=> interpolated["childCount"], :infantInLapCount=>interpolated["infantInLapCount"], :infantInSeatCount=>interpolated['infantInSeatCount'], :seniorCount=>interpolated["seniorCount"]}, :slice=>[{:kind=>"qpxexpress#sliceInput", :origin=> interpolated["origin"].to_s , :destination=> interpolated["destination"].to_s , :date=> interpolated["date"].to_s }], :solutions=> interpolated["solutions"]}}
      body = JSON.generate(post_params)
      request = HTTParty.post(event_url, :body => body, :headers => {"Content-Type" => "application/json"})
      events = JSON.parse request.body
      create_event :payload => events
    end

    def event_url
      endpoint = 'https://www.googleapis.com/qpxExpress/v1/trips/search?key=' + "#{URI.encode(interpolated[:qpx_api_key].to_s)}"
    end
  end
end
