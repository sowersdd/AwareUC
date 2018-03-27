=begin
	Created by Cailin Pitt on 10/15/2015
	Ported for UC by Dane Sowers on 3/14/2018
	
	Ruby script that webscrapes crime information from the Columbus PD and the OSU PD's online logs and emails it to users.
=end

# Mechanize gets the website and transforms into HTML file.
require 'mechanize'
# Nokogiri gets the website data that could be read later on.
require 'nokogiri'
# Mail sends out information
require 'mail'
# resolv-replace.rb is more for testing, supplies nice error statements in case this script runs into network issues
require 'resolv-replace.rb'
# Need HTTParty gem for making requests to CPD API
require 'httparty'

# Get yesterday's date
# yesterday = Date.today.prev_day
yesterday = Date.parse('March 19, 2018')
yesterdayWithDay = yesterday.strftime('%A, %B %d, %Y')
	
# Initialize new Mechanize agent
# Pi takes a longer time to load web pages, increase timeouts in order to avoid socketerrors
agent = Mechanize.new
agent.open_timeout = 60
agent.read_timeout = 60

# Chose Safari because I like Macs
agent.user_agent_alias = "Mac Safari" 

# Declare variable to hold crime information
crimeHTML = ""

passArray = IO.readlines('/Users/Dane/Documents/p')
key = passArray[1].delete!("\n")

options = { :address      			=> "smtp.gmail.com",
          :port                 => 587,
          :user_name            => 'aware.cincy',
          :password             => passArray[0].delete!("\n"),
          :authentication       => 'plain',
          :enable_starttls_auto => true  }

# Set up mail options, authenticate
Mail.defaults do
  delivery_method :smtp, options
end

# If website is down, we'll retry visiting it three times.
crimeTableInfo = ""
websiteDown = false
retries = 3

mapURL = "<img src = 'https://maps.googleapis.com/maps/api/staticmap?zoom=13&center=university+of+cincinnati&size=370x330&scale=2&maptype=roadmap"
offCampusArray = []

begin
websiteURL = "https://data.cincinnati-oh.gov/resource/cxea-umgx.json?$where=closed_time_incident > '#{yesterday.strftime('%Y-%m-%dT00:00:00.000')}' AND closed_time_incident < '#{yesterday.strftime('%Y-%m-%dT23:59:59.999')}'  AND neighborhood in ('CLIFTON', 'CUF', 'CORRYVILLE') AND (disposition_text LIKE '%25ARREST%25' OR disposition_text LIKE '%25OFFENSE%25' OR disposition_text LIKE '%25THEFT%25') AND (incident_type_id NOT IN ('SS', 'PRIS', 'ST', 'WANT', 'INV', 'WAR'))"
# Try to direct to CPD API
response = HTTParty.get(websiteURL)
json_response = response.parsed_response
# Rescue from HTTP GET request to CPD API
rescue
	if retries > 0
		retries -= 1
		sleep 5
		retry
	else
		websiteDown = true
		crimeHTML += "<h1>0 Off-campus crimes for #{yesterday} - Website Down</h1>"
		crimeHTML += '<p>The CPD Data API is currently down.</p><p>Please be sure to check <a href="https://data.cincinnati-oh.gov">the City of Cincinnat data portal</a> later today or tomorrow for any updates.</p>'
	end
else
	# Else it loaded, continue with execution of script
	for i in 0...json_response.length
		crime = json_response[i]
		crime_date = DateTime.parse(crime['closed_time_incident'])
		description = crime['incident_type_desc']
		description.gsub!(" J/O OR IN PROGRESS", "")
		description.gsub!(" REPORT", "")
		description.gsub!(" J/O", "")
		crime_info = Hash.new 
		crime_info["event_number"] = crime['event_number']
		crime_info["crime_type"] = description
		crime_info["address"] = crime['address_x']
		crime_info["latitude"] = crime['latitude_x']
		crime_info["longitude"] = crime['longitude_x']
		offCampusArray << crime_info
	end
end

if offCampusArray.length > 0
	for m in 0...offCampusArray.size
		crime = offCampusArray[m]
		crimeTableInfo += '<tr>'
		crimeTableInfo += '<td>' + (m + 1).to_s + '</td>'
		crimeTableInfo += '<td>' + crime['crime_type'] + '</td>'
		crimeTableInfo += '<td>' + crime['address'] + '</td>'
		crimeTableInfo += '<td>' + crime['event_number'] + '</td>'
		crimeTableInfo += '</tr>'
		
		mapURL += "&markers=color:blue%7Clabel:#{m + 1}%7C#{crime['latitude']},#{crime['longitude']}"
	end
end

if offCampusArray.size > 0
	# Add information to result if there were off-campus crimes
	mapURL += "&maptype=terrain&key=" + key + "' />"
	crimeHTML += mapURL
	crimeHTML += "<h1>#{offCampusArray.size} Off-campus crimes for #{yesterdayWithDay}</h1>"
	crimeHTML += '<table style="width:80%;text-align: left;" cellpadding="10"><tbody><tr><th>Number on Map</th><th>Description</th><th>Location</th><th>Event Number</th></tr>'
	crimeHTML += crimeTableInfo
	crimeHTML += '</tbody></table>'
elsif  ((offCampusArray.size == 0) && (websiteDown == false))
	# No crimes reported for the day we searched
	crimeHTML += "<h1>0 Off-campus crimes for #{yesterdayWithDay}</h1>"
	crimeHTML += '<p>This is either due to no crimes occuring off-campus, or the Cincinnati Police Department forgetting to upload crime information.</p><p>Please be sure to check <a href="https://data.cincinnati-oh.gov">the City of Cincinnat data portal</a> later today or tomorrow for any updates.</p>'
end

websiteDown = false
retries = 0
on_campus_array = []
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
		sleep 5
		retry
	else
		websiteDown = true
		crimeHTML += "<h1>0 On-campus crimes for #{yesterdayWithDay} - Website Down</h1>"
		crimeHTML += '<p>The UC Police Department\'s website is currently down.</p><p>Please be sure to check <a href="http://www.uc.edu/webapps/publicsafety/policelog2.aspx">the UCPD web portal</a> later today or tomorrow for any updates.</p>'
	end
else
	uc_crimes = Nokogiri::HTML(page.body).css("table").css("td")
	if (uc_crimes.length / 8) == 0
		puts "No UC crimes"
	else
		#Else there were crimes, extract and add to resuls
		i = 7
		while i < uc_crimes.length do
			crime_info = Hash.new
			crime_info['report_number'] = uc_crimes[i + 2].text
			crime_info['campus'] = uc_crimes[i].text
			crime_info['incident_type'] = uc_crimes[i + 3].text
			crime_info['location'] = uc_crimes[i + 5].text
			crime_info['description'] = uc_crimes[i + 4].text
			on_campus_array << crime_info
			i += 7
		end
	end
end

if on_campus_array.size > 0
	mapURL = "<img src = 'https://maps.googleapis.com/maps/api/staticmap?zoom=14&center=university+of+cincinnati&size=370x330&scale=2&maptype=roadmap"
	crimeHTML = crimeHTML + "<br><br>"
	crimeHTML = crimeHTML + "<h1>#{on_campus_array.size} On-campus crimes for #{yesterdayWithDay}</h1>"

	crimeTable = '<table style="width:80%;text-align: left;" cellpadding="10"><tbody><tr><th>Number on Map</th><th>Report Number</th><th>Campus</th><th>Incident Type</th><th>Location</th><th>Description</th></tr>'

	for i in 0...on_campus_array.size do
		crimeTable = crimeTable + '<tr>'
		crimeTable = crimeTable + '<td>' + (i + 1).to_s + '</td>'
		crimeTable = crimeTable + '<td>' + on_campus_array[i]['report_number'] + '</td>'
		crimeTable = crimeTable + '<td>' + on_campus_array[i]['campus'] + '</td>'
		crimeTable = crimeTable + '<td>' + on_campus_array[i]['incident_type'] + '</td>'
		crimeTable = crimeTable + '<td>' + on_campus_array[i]['location'] + '</td>'
		crimeTable = crimeTable + '<td>' + on_campus_array[i]['description'] + '</td>'
		crimeTable = crimeTable + '</tr>'
		location = on_campus_array[i]['location']
		location.delete!("&")
	
		if location.include? " "
			mapURL += "&markers=color:blue%7Clabel:#{i + 1}%7C" + location.gsub!(/\s+/, '+') + "+cincinnati+ohio"
		else
			mapURL += "&markers=color:blue%7Clabel:#{i + 1}%7C" + location + "+cincinnati+ohio"
		end
	end
	# Insert on-campus crime information into table
	mapURL += "&maptype=terrain&key=" + key + "' />"
	crimeHTML += mapURL
	crimeHTML += crimeTable
	crimeHTML += '</tbody></table>'
	# End table	
elsif on_campus_array.size == 0 && websiteDown == false
	crimeHTML = crimeHTML + "<h1>0 On-campus crimes for #{yesterdayWithDay}</h1>"
	crimeHTML = crimeHTML + '<p>This is either due to no crimes occuring on-campus, or UCPD forgetting to upload crime information.</p><p>Please be sure to check <a href="http://www.uc.edu/webapps/publicsafety/policelog2.aspx">the UCPD web portal</a> later today or tomorrow for any updates.</p>'
end	

mail = Mail.new({
		:to => 'aware.cincy@gmail.com',
		:from => 'aware.cincy@gmail.com',
		:subject => "AwareUC - #{yesterdayWithDay}"
	});

mail.attachments['AwareOSULogo.png'] = File.read('./images/AwareOSULogo.png')
pic = mail.attachments['AwareOSULogo.png']

html_part = Mail::Part.new do
		 content_type 'text/html; charset=UTF-8'
		 body "<center><img src='cid:#{pic.cid}'></center>" + crimeHTML + '<br><p>Best,</p><p>AwareOSU</p><br><p>P.S. Please visit this <a href="http://goo.gl/forms/n3q6D53TT3">link</a> to subscribe/unsubscribe.</p>'
	end
	# Insert email body into mail object

mail.html_part  = html_part
mail.deliver!
