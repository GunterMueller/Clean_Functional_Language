definition module htmlDatabase

import htmlExceptions

universalDB :: !(!Init,!Lifespan,!a,!String) !(String a -> Judgement) !*HSt -> (a,!*HSt) | iData a
