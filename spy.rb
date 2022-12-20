#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'ostruct'
require 'faraday'
require 'lightly'
require 'geocoder'
require 'ruby-progressbar'

API = 'https://airspy.com/directory/status.json'

api_cache = Lightly.new life: '1m'
loc_cache = Lightly.new life: '365d'

class Numeric
  def hz_to_mhz
    (self / 1_000_000).round 2
  end
end

servers = api_cache.get 'items' do
  response = Faraday.get API
  JSON.parse(response.body, object_class: OpenStruct).servers
end

online_servers = servers.select(&:online)

progressbar = ProgressBar.create total: online_servers.size

online_servers.each do |item|
  aloc = item.antennaLocation
  coords = [aloc.lat, aloc.long]
  item.loc = loc_cache.get coords.join('#') do
    results = Geocoder.search(coords)
    r = results.first
    [r.country, r.city]
  end
  item.country = item.loc.first || '?'
  item.city = item.loc.last || '?'
  item.freq_range = [
    item.minimumFrequency.hz_to_mhz,
    item.maximumFrequency.hz_to_mhz
  ]
  progressbar.increment
end

servers_by_country = online_servers.sort_by(&:country).group_by(&:country)

servers_by_country.each do |country, items|
  puts
  puts "=== #{country} ==="
  items.sort_by(&:city).each do |item|
    info = [
      "#{'%-15s' % item.streamingHost} #{item.streamingPort}",
      "#{'%10s' % item.freq_range.join('..')} MHz",
      item.loc.last
    ]
    puts info.join("\t")
  end
end
