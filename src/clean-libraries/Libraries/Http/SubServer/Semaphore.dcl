definition module Semaphore

CreateSemaphore 	:: !Int !Int !Int !{#Char} !*World -> (!Int,!*World);
WaitForSingleObject :: !Int !Int !*World -> (!Int,!*World);
ReleaseSemaphore 	:: !Int !Int !Int !*World -> (!Int,!*World);
CloseHandle 		:: !Int !*World -> (!Int,!*World);
