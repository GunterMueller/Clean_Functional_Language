module travel

import StdEnv, htmlTask, htmlTrivial

// (c) 2007 MJP

// Test for multiple choice
// One can choose to book a flight, hotel and / or a car
// One by one the chosen bookings will be handled
// The bill is made up in the end

derive gForm []
derive gUpd  []

Start world = doHtmlServer (singleUserTask 0 True (foreverTask travel)) world

travel :: (Task Void)
travel 
= 			[Txt "Book your journey:",Br,Br]
			?>>	seqTasks	[ ( "Choose Booking options:"
							  , mchoiceTasks	[ ("Book_Flight",BookFlight)
												, ("Book_Hotel", BookHotel)
												, ("Book_Car",   BookCar)
												]
							  )
							, ( "Confirm Booking:"
							  , buttonTask "Confirm" (return_V [])
							  )
							]
				-||- 
				buttonTask "Cancel" (return_V [])
	=>> \booking -> [Txt "Handling bookings:",Br,Br]
					?>> handleBookings booking
where
	handleBookings booking
	| isNil	booking	= 		editTask "Cancelled" Void
	| otherwise		= 		editTask "Pay" (Dsp (calcCosts booking))
					  #>>	editTask "Paid" Void
	where
		calcCosts booked = sum [cost \\ (_,_,_,cost) <- hd booked]

		isNil [] = True
		isNil _ = False

	BookFlight  = editTask "BookFlight" (Dsp "Flight Number","",Dsp "Costs",0) 	<<@ Submit
	BookHotel  	= editTask "BookHotel" 	(Dsp "Hotel Name","",Dsp "Costs",0)		<<@ Submit
	BookCar  	= editTask "BookCar" 	(Dsp "Car Brand","",Dsp "Costs",0)		<<@ Submit


Dsp = DisplayMode 
