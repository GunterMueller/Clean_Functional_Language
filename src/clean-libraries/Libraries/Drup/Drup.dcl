definition module Drup

import DrupGeneric, StdMaybe

:: Drup

openDrup :: !String !(Maybe .a) !*World -> (!Chunk .a, !*Drup, !*World) | write{|*|} a
closeDrup :: !*Drup !*World -> *World

chunk :: !*Drup -> (!Chunk .a, !*Drup)
chunkValue :: !(Chunk .a) !*Drup -> (!.a, !*Drup) | read{|*|} a
updateChunk :: !(Chunk .a) !.a !*Drup -> *Drup | write{|*|} a

unsafeChunkValue :: !Pointer !*Drup -> (!.a, !*Drup) | read{|*|} a
unsafeUpdateChunk :: !Pointer !.a !*Drup -> *Drup | write{|*|} a

derive write {}, {!}, String
derive read {}, {!}, String
