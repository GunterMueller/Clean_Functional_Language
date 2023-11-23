implementation module DrupGeneric

import DrupBasic
import StdGeneric, StdInt

Equal x y :== x == y

generic write a :: !.a !*Write -> *Write
generic read a :: !*Write -> *Read .a

write{|OBJECT|} write_a object acc = case object of
	OBJECT x = write_a x acc

write{|EITHER|} write_a write_b either acc = case either of
	LEFT x = write_a x acc
	RIGHT y = write_b y acc

write{|CONS of {gcd_index, gcd_type_def={gtd_num_conses}}|} write_a cons acc = case cons of
	CONS x = write_a x (writeCons gcd_index gtd_num_conses acc)

write{|PAIR|} write_a write_b pair acc = case pair of
	PAIR x y = write_b y (write_a x acc) 

write{|FIELD|} write_a field acc = case field of
	FIELD x = write_a x acc

write{|UNIT|} unit acc = acc

write{|Char|} char acc = writeChar char acc

write{|Int|} int acc = writeInt int acc

write{|Real|} real acc = writeReal real acc

write{|Bool|} bool acc = writeBool bool acc

read{|OBJECT|} read_a acc = case read_a acc of
	Read x left file = Read (OBJECT x) left file
	Fail file = Fail file

read{|EITHER|} read_a read_b acc = case acc of
	Write left file = readEITHER2 read_a read_b left file
	
readEITHER2 read_a read_b left file = case read_a (Write left file) of
	Read x left file = Read (LEFT x) left file
	Fail file = readEITHER3 read_b (Write left file)

readEITHER3 read_b acc = case read_b acc of
	Read y left file = Read (RIGHT y) left file
	Fail file = Fail file

read{|CONS of {gcd_index, gcd_type_def={gtd_num_conses}}|} read_a acc = case readCons gcd_index gtd_num_conses acc of
	Read True left file = readCONS2 read_a (Write left file)
	Read _ left file = Fail file
	Fail file = Fail file

readCONS2 read_a acc = case read_a acc of
	Read x left file = Read (CONS x) left file
	Fail file = Fail file

read{|PAIR|} read_a read_b acc = case read_a acc of
	Read x left file = readPAIR2 read_b x (Write left file)
	Fail file = Fail file

readPAIR2 read_b x acc = case read_b acc of
	Read y left file = Read (PAIR x y) left file
	Fail file = Fail file

read{|FIELD|} read_a acc = case read_a acc of
	Read x left file = Read (FIELD x) left file
	Fail file = Fail file

read{|UNIT|} acc = case acc of
	Write left file = Read UNIT left file

read{|Char|} acc = readChar acc

read{|Int|} acc = readInt acc

read{|Real|} acc = readReal acc

read{|Bool|} acc = readBool acc

write{|Chunk|} _ chunk acc = writeChunk chunk acc

read{|Chunk|} _ acc = readChunk acc

write{|Pointer|} chunk acc = writeChunk {chunk = chunk} acc

read{|Pointer|} acc = case readChunk acc of
	Read {chunk} left file -> Read chunk left file
	Fail file -> Fail file

derive write [], (,), (,,), (,,,)
derive read [], (,), (,,), (,,,)

derive bimap Read
