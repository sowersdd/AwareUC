#!/usr/bin/env ruby
=begin
	Created by Cailin Pitt on 10/15/2015
	Edited by Will Sloan on 3/9/2016
	Ported for UC by Dane Sowers on 3/14/2018

	Ruby script that webscrapes crime information from the Columbus PD and the UC PD's online logs and emails it to users.
=end

# Mechanize gets the website and transforms into HTML file.
require 'mechanize'

# Nokogiri gets the website data that could be read later on.
require 'nokogiri'

# resolv-replace.rb is more for testing, supplies nice error statements in case this script runs into network issues
require 'resolv-replace.rb'
require 'byebug'

#HELLO WORLD!

# Get yesterday's date
# yesterday = Date.today.prev_day
yesterday = Date.parse("February 6, 2018")

# Initialize new Mechanize agent
agent = Mechanize.new
agent.open_timeout = 60
agent.read_timeout = 60

# Chose Safari because I like Macs
agent.user_agent_alias = "Mac Safari"

# If website is down, we'll retry visiting it three times.
retries = 0
websiteDown = false

# This array contains the districts we want to get crime info from
districtArray = [ 'dis33', 'dis30', 'dis34', 'dis53', 'dis50', 'dis43', 'dis40', 'dis41', 'dis42', 'dis44' ]


mapURL = ""
crimeNum = 0

# for i in 0...districtArray.length
# 	# Sleep between each request
# 	sleep 4
# 	begin
# 		websiteURL = "http://www.columbuspolice.org/reports/Results?from=datePlaceholder&to=datePlaceholder&loc=locationPlaceholder&types=9"
# 		# Insert search info into URL
# 		websiteURL.gsub!('datePlaceholder', yesterday).gsub!('locationPlaceholder', districtArray[i])
# 		# Try to direct to Columbus PD report website
# 		page = agent.get websiteURL
# 	# Rescue from HTTP GET request to CPD Site
# 	rescue
# 		if retries < 3
# 			retries += 1
# 			puts "Request #{retries} to CPD site failed, trying again"
# 			sleep 5
# 			retry
# 		else
# 			websiteDown = true
# 			puts "CPD Site unavailable, skipping"
# 			break
# 		end
# 	# Successful load of CPD site
# 	else
# 		resultPage = Nokogiri::HTML(page.body)

# 		# Use this span class to find error
# 		error_capture = resultPage.css("span[class='ErrorLabel']")

# 		if error_capture.text.to_s.eql? "Your search produced no records."
# 			puts "No crimes committed in CPD district #{districtArray[i]}"
# 		else
# 			cpd_elements = resultPage.css("table[class='mGrid']").css('td').css('tr')

# 			# Get crime information
# 			crimeNum = cpd_elements.length
# 			i = 0
# 			j = 0
# 			linkIndex = 1

# 			while ((i < crimeNum) && (i < 145)) do
# 				report = '';
# 				for j in 11...crimeReportNumbers[linkIndex]["onclick"].length - 1
# 					char = '' + crimeReportNumbers[linkIndex]["onclick"][j]
# 					report += char
# 				end
# 				# This loop takes care of setting up the links to each individual crime's page, where more information is listed.
# 				puts "{"
# 				puts "\tOffense: #{crimeInfo[i + 1].text}"
# 				puts "\tVictim: #{crimeInfo[i + 2].text}"
# 				puts "\tLocation: #{crimeInfo[i + 4].text}"
# 				puts "\tReport Number #{report}"
# 				puts "}"

# 				i += 5
# 				linkIndex += 1
# 			end

# 			# Crimes are retrieved from a table seperated by pages. Each page holds 29 crimes.
# 			# JavaScript is used for pagination, and since Mechanize/Nokogiri cannot interact with JS (only HTML),
# 			# the program can only retrieve the first 29 crimes (hence i < 145 [Each crime has 5 fields, 5 * 29 = 145])
# 			# Until I figure out how to deal with pagination, we will only return the first 29 crimes.
# 			# We rarely have more than 29 crimes, so this is a rare case, however it's something I still want to take care of.
# 		end
# 	end
# end

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
