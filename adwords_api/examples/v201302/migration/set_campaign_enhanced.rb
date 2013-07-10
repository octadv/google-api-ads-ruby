#!/usr/bin/env ruby
# Encoding: utf-8
#
# Author:: api.dklimkin@gmail.com (Danial Klimkin)
#
# Copyright:: Copyright 2013, Google Inc. All Rights Reserved.
#
# License:: Licensed under the Apache License, Version 2.0 (the "License");
#           you may not use this file except in compliance with the License.
#           You may obtain a copy of the License at
#
#           http://www.apache.org/licenses/LICENSE-2.0
#
#           Unless required by applicable law or agreed to in writing, software
#           distributed under the License is distributed on an "AS IS" BASIS,
#           WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#           implied.
#           See the License for the specific language governing permissions and
#           limitations under the License.
#
# This example sets the enhanced bit in a given campaign. To get campaigns, run
# get_campaigns.rb.
#
# Tags: CampaignService.mutate

require 'adwords_api'

def set_campaign_enhanced(campaign_id)
  # AdwordsApi::Api will read a config file from ENV['HOME']/adwords_api.yml
  # when called without parameters.
  adwords = AdwordsApi::Api.new

  # To enable logging of SOAP requests, set the log_level value to 'DEBUG' in
  # the configuration file or provide your own logger:
  # adwords.logger = Logger.new('adwords_xml.log')

  campaign_srv = adwords.service(:CampaignService, API_VERSION)

  # Prepare for updating campaign. Note: After setting the enhanced value to
  # true, setting it back to false will generate an ApiError.
  operation = {
    :operator => 'SET',
    :operand => {
      :id => campaign_id,
      :enhanced => true
    }
  }

  # Update campaign.
  response = campaign_srv.mutate([operation])
  if response and response[:value]
    campaign = response[:value].first
    puts "Campaign ID %d was successfully updated, enhanced bit set to: '%s'." %
        [campaign[:id], campaign[:enhanced]]
  else
    puts 'No campaigns were updated.'
  end
end

if __FILE__ == $0
  API_VERSION = :v201302

  begin
    # ID of a campaign to be updated with the enhanced value.
    campaign_id = 'INSERT_CAMPAIGN_ID_HERE'.to_i
    set_campaign_enhanced(campaign_id)

  # Authorization error.
  rescue AdsCommon::Errors::OAuth2VerificationRequired => e
    puts "Authorization credentials are not valid. Edit adwords_api.yml for " +
        "OAuth2 client ID and secret and run misc/setup_oauth2.rb example " +
        "to retrieve and store OAuth2 tokens."
    puts "See this wiki page for more details:\n\n  " +
        'http://code.google.com/p/google-api-ads-ruby/wiki/OAuth2'

  # HTTP errors.
  rescue AdsCommon::Errors::HttpError => e
    puts "HTTP Error: %s" % e

  # API errors.
  rescue AdwordsApi::Errors::ApiException => e
    puts "Message: %s" % e.message
    puts 'Errors:'
    e.errors.each_with_index do |error, index|
      puts "\tError [%d]:" % (index + 1)
      error.each do |field, value|
        puts "\t\t%s: %s" % [field, value]
      end
    end
  end
end
