#!/usr/bin/env ruby
=begin
	Created by Cailin Pitt on 10/15/2015
	Edited by Will Sloan on 3/9/2016
	Ported for UC by Dane Sowers on 3/14/2018

	Ruby script that webscrapes crime information from the CPD API and UCPD online logs and emails it to users.
=end

# Mechanize gets the website and transforms into HTML file.
require 'mechanize'

# Nokogiri gets the website data that could be read later on.
require 'nokogiri'

# Need HTTParty gem for making requests to CPD API
require 'httparty'

# resolv-replace.rb is more for testing, supplies nice error statements in case this script runs into network issues
require 'resolv-replace.rb'
require 'byebug'

# Get yesterday's date
yesterday = Date.today.prev_day

# Initialize new Mechanize agent
agent = Mechanize.new
agent.open_timeout = 60
agent.read_timeout = 60

# Chose Safari because I like Macs
agent.user_agent_alias = "Mac Safari"

# If website is down, we'll retry visiting it three times.
retries = 0
websiteDown = false

mapURL = ""
crimeNum = 0

begin
	websiteURL = "https://data.cincinnati-oh.gov/resource/cxea-umgx.json?$where=closed_time_incident > '2018-03-25T00:00:00.000' AND closed_time_incident < '2018-03-26T00:00:00.000'  AND neighborhood in ('CLIFTON', 'CUF', 'CORRYVILLE') AND (disposition_text LIKE '%25ARREST%25' OR disposition_text LIKE '%25OFFENSE%25' OR disposition_text LIKE '%25THEFT%25') AND (incident_type_id NOT IN ('SS', 'PRIS', 'ST', 'WANT'))"
	# Try to direct to CPD API
	response = HTTParty.get(websiteURL)
	json_response = response.parsed_response
# Rescue from HTTP GET request to CPD API
rescue
	if retries < 3
		retries += 1
		puts "Request #{retries} to CPD API failed, trying again"
		sleep 5
		retry
	else
		websiteDown = true
		puts "CPD API unavailable, skipping"
	end
# Successful load of CPD API
else
	for i in 0...json_response.length
		crime = json_response[i]
		crime_date = DateTime.parse(crime['closed_time_incident'])
		description = crime['incident_type_desc']
		description.gsub!(" J/O OR IN PROGRESS", "")
		description.gsub!(" REPORT", "")
		description.gsub!(" J/O", "")
		puts "{"
		puts "\tEvent Number: #{crime['event_number']}"
		puts "\tCrime Type: #{description}"
		puts "\tDate: #{crime_date.strftime("%m/%d/%Y")}"
		puts "\tAddress: #{crime['address_x']}"
		puts "}"
	end
end

websiteDown = false
retries = 0
begin
	query = Hash.new
	query['startm'] = yesterday.month
    query['startd'] = yesterday.day
	query['starty'] = yesterday.year
	query['endm'] = yesterday.month
    query['endd'] = yesterday.day
	query['endy'] = yesterday.year
	
	page = agent.post "http://www.uc.edu/webapps/publicsafety/policelog2.aspx", query, { "Content-Type" => "application/x-www-form-urlencoded" }
	# Rescue failure of POST to UC Police Site
rescue
	if retries < 3
		retries += 1
		puts "Request #{retries} to UC site failed, trying again"
		sleep 5
		retry
	else
		websiteDown = true
		puts "UC Site unavailable, skipping"
	end
else
	uc_crimes = Nokogiri::HTML(page.body).css("table").css("td")
	if (uc_crimes.length / 8) == 0
		puts "No UC crimes"
	else
		#Else there were crimes, extract and add to resuls
		i = 7
		while i < uc_crimes.length do
			puts "{"
			puts "\tReport Number: #{uc_crimes[i + 2].text}"
			puts "\tCampus: #{uc_crimes[i].text}"
			puts "\tIncident Type: #{uc_crimes[i + 3].text}"
			puts "\tLocation: #{uc_crimes[i + 5].text}"
			puts "\tDescription: #{uc_crimes[i + 4].text}"
			puts "}"
			i += 7
		end
	end
end