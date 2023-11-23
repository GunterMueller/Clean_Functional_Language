definition module version

GetFileVersionInfoSize :: !{#Char} !{#Char} !*Int -> (!Int,!*Int)
GetFileVersionInfo :: !{#Char} !Int !Int !{#Char} !*Int -> (!Int,!*Int)
VerQueryValue :: !{#Char} !{#Char} !{#Char} !{#Char} !*Int  -> (!Int,!*Int)
