definition module stateHandlingIData

import stateHandling
import StdHtml

guestAccountStore :: ((Bool,ConfAccount) -> (Bool,ConfAccount)) !*HSt -> (Form (Bool,ConfAccount),!*HSt)

// login handling pages

loginHandlingPage  :: !ConfAccounts !*HSt -> (Maybe ConfAccount,[BodyTag],!*HSt)

// Conference Manager Pages 

modifyStatesPage 			:: !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
assignPapersConflictsPage 	:: !ConfAccounts !*HSt -> ([BodyTag],!*HSt)

// Showing information

showPapersPage 				:: !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
showReportsPage 			:: !ConfAccount !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
discussPapersPage 			:: !ConfAccount !ConfAccounts !*HSt -> ([BodyTag],!*HSt)
showPapersStatusPage 			:: !ConfAccount !ConfAccounts !*HSt -> ([BodyTag],!*HSt)

// Changing user settings

changeInfo 					:: !ConfAccount !*HSt -> ([BodyTag],!*HSt)
submitPaperPage 			:: !ConfAccount !*HSt -> ([BodyTag],!*HSt)

// Changes made by a referee

submitReportPage 			:: !ConfAccount !ConfAccounts !*HSt -> ([BodyTag],!*HSt)

