definition module HttpTextUtil

//Trim functions
text_trim :: String -> String
text_ltrim :: String -> String
text_rtrim :: String -> String

//Split and join
text_split :: String String -> [String]
text_join ::  String [String] -> String

//Searching and replacement
text_indexOf :: String String -> Int
text_replace :: (String,String) String -> String
text_replaceMany :: [(String,String)] String -> String

