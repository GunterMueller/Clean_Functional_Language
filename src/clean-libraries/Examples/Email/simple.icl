module simple

import Email

email = 	{ email_from	= "example@example.net"
			, email_to		= "example@example.net"
			, email_subject	= "Clean e-mail example"
			, email_body	= "This is an example of an e-mail sent from Clean"
			}
			
options = [EmailOptSMTPServer "smtp.example.net"]

Start :: *World -> String
Start world
	# (ok,world)	= sendEmail options email world
	| ok			= "Email sent succesfully"
	| otherwise		= "Something went wrong"