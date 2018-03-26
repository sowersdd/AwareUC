#!/usr/bin/env ruby
=begin
	Created by Cailin Pitt on 10/15/2015
	Edited by Will Sloan on 3/9/2016
	Ported for UC by Dane Sowers on 3/14/2018

	Ruby script that webscrapes crime information from the SpotCrime and UCPD online logs and emails it to users.
=end

# Mechanize gets the website and transforms into HTML file.
require 'mechanize'

# Nokogiri gets the website data that could be read later on.
require 'nokogiri'

# Need Watir gem because there are AJAX requests on the SpotCrime page
# NOTE: Make sure to install chromedriver 2.25 (http://chromedriver.storage.googleapis.com/index.html?path=2.25/)
require 'watir'

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

browser = Watir::Browser.new

# If website is down, we'll retry visiting it three times.
retries = 0
websiteDown = false

# This array contains the districts we want to get crime info from
neighborhoodArray = [ 'clifton', 'corryville', 'cuf' ]

mapURL = ""
crimeNum = 0

for i in 0...neighborhoodArray.length
	# Sleep between each request
	sleep 4
	begin
		websiteURL = "https://spotcrime.com/oh/cincinnati/locationPlaceholder"
		# Insert search info into URL
		websiteURL.gsub!('locationPlaceholder', neighborhoodArray[i])
		# Try to direct to SpotCrime report website
		browser.goto(websiteURL)
	# Rescue from HTTP GET request to SpotCrime Site
	rescue
		if retries < 3
			retries += 1
			puts "Request #{retries} to SpotCrime site failed, trying again"
			sleep 5
			retry
		else
			websiteDown = true
			puts "SpotCrime Site unavailable, skipping"
			break
		end
	# Successful load of SpotCrime site
	else
		resultPage = Nokogiri::HTML(browser.html)
		crime_blocks = resultPage.css("div.crime-list")
		for j in 0...crime_blocks.length
			crimes_in_block = crime_blocks[j].css("a")
			for k in 0...crimes_in_block.length
				crime_date = Date.strptime(crimes_in_block[k].css('.crime-date').text, '%m/%d/%Y')
				if crime_date >= yesterday
					puts "{"
					puts "\tDetail Link: #{crimes_in_block[k]['href']}"
					puts "\tCrime Type: #{crimes_in_block[k].css('h4').text}"
					puts "\tDate: #{crime_date}"
					puts "\tAddress #{crimes_in_block[k].css('.crime-address').text}"
					puts "}"
				else
					break
				end
			end
		end
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