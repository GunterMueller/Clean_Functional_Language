implementation module osbitmap

//	Clean object I/O library, version 1.2

import StdClass, StdFile, StdInt, StdString
import ostypes, ostoolbox, osrgn
import memory, quickdraw, memoryaccess
import resources, structure

//import dodebug
trace_n _ f :== f

::	Bitmap
	= OSBitmap !OSBitmap

::	OSBitmap
	=	{	bitmapSize		:: !(!Int,!Int)		// The size of the bitmap
		,	bitmapContents	:: !Handle		// The handle to the bitmap information (a string)
		}

PictHeaderSize :== 512

toBitmap	:: !OSBitmap -> Bitmap
toBitmap b = OSBitmap b

fromBitmap	:: !Bitmap -> OSBitmap
fromBitmap (OSBitmap b) = b

osOpenBitmap :: !Int !*OSToolbox -> (!Bool,!OSBitmap,!*OSToolbox)
osOpenBitmap pictID  tb
	# (pictHandle,tb)	= Get1Resource "PICT" pictID tb
	| pictHandle == 0
		= (False,noBitmap,tb)
	# (pictPtr,tb)		= DereferenceHandle pictHandle tb
	# (top,tb)			= LoadWord (pictPtr + 2) tb
	# (left,tb)			= LoadWord (pictPtr + 4) tb
	# (bottom,tb)		= LoadWord (pictPtr + 6) tb
	# (right,tb)		= LoadWord (pictPtr + 8) tb
	# bitmap			= {bitmapSize=(right-left,bottom-top),bitmapContents=pictHandle}
	= (True, bitmap, tb)
where
	noBitmap = {bitmapSize=(0,0),bitmapContents=0}

//	OSreadBitmap reads a bitmap from a file.
osReadBitmap :: !*File -> (!Bool,!OSBitmap,!*File)
osReadBitmap file
	# (nrBytes,file)	= fileSize file
	# dataBytes			= nrBytes - PictHeaderSize
	# (_,file)			= fseek file PictHeaderSize FSeekSet
	# (ok,[_,top,left,bottom,right:_],file)
						= readWords 5 file
	| not ok
		= trace_n "OSreadBitmap: 1" (False,noBitmap,file)
	# (_,file)			= fseek file PictHeaderSize FSeekSet
	# (contents,file)	= freads file dataBytes
	# (handle,error,tb) = NewHandle dataBytes OSNewToolbox
	| error<>0
		= trace_n ("OSreadBitmap: 2 "+++toString dataBytes+++","+++toString error) (False,noBitmap,file)
	# (handle,tb)		= copy_string_to_handle` contents handle dataBytes tb
	# (wrong,file)		= ferror file
	  bitmap			= if wrong
	  						noBitmap
	  						{bitmapSize=(right-left,bottom-top),bitmapContents=handle}
	= trace_n ("OSreadBitmap",dataBytes,(left,top,right,bottom)) (not wrong,bitmap,file)
where
	copy_string_to_handle` c h s t
		#! t = copy_string_to_handle c h s t
		= (h,t)
	noBitmap = {bitmapSize=(0,0),bitmapContents=0}
	
	fileSize :: !*File -> (!Int,!*File)
	fileSize file
		# (cur,file) = fposition file
		# (_,  file) = fseek     file 0 FSeekEnd
		# (end,file) = fposition file
		# (_,  file) = fseek     file cur FSeekSet
		= (end,file)
	
	readWords :: !Int !*File -> (!Bool,![Int],!*File)
	readWords n file
		| n==0
		= (True,[],file)
		# (_, c, file)	= freadc file
		# (ok,d, file)	= freadc file
		  value			= toInt c << 8 + toInt d
		| not ok
		= (ok,[],file)
		# (ok,words,file)	= readWords (n-1) file
		= (ok,[value:words],file)

//	OSgetBitmapSize returns the size of the bitmap
osGetBitmapSize :: !OSBitmap -> (!Int,!Int)
osGetBitmapSize {bitmapSize} = bitmapSize

//	OSgetBitmapContent returns the content string of the bitmap
osGetBitmapContent :: !OSBitmap -> {#Char}
osGetBitmapContent {bitmapContents}
	# (handleSize,tb)	= GetHandleSize bitmapContents OSNewToolbox
	# (string,tb)		= handle_to_string bitmapContents handleSize tb
	| tb == OSNewToolbox
		= string
	= string

/*	OSresizeBitmap (w,h) bitmap
		resizes the argument bitmap to the given size.
		It is assumed that w and h are not negative.
*/
osResizeBitmap :: !(!Int,!Int) !OSBitmap -> OSBitmap
osResizeBitmap newSize {bitmapContents}
	= { bitmapSize=newSize, bitmapContents=bitmapContents }

/*	OSdrawBitmap bitmap pos origin isScreenOutput pictContext
		draws the argument bitmap with the left top corner at pos, given the
		current origin and drawing context.
		The isScreenOutput MUST be False when producing printer output. For
		screen output this is not the case,
		but setting it to True is much more efficient. 
*/
osDrawBitmap :: !OSBitmap !(!Int,!Int) !(!Int,!Int) !Bool !OSPictContext !*OSToolbox -> (!OSPictContext,!*OSToolbox)
osDrawBitmap {bitmapSize=(w,h),bitmapContents} pos=:(px,py) origin=:(ox,oy) isScreenOutput pictContext tb
	# tb = trace_n ("OSdrawBitmap: (px,py,ox,oy,w,h): "+++toString (px,py,ox,oy,w,h)) tb
	# (port,tb) = QGetPort tb
	# tb = trace_n ("OSdrawBitmap: port: "+++toString port) tb
	# (clip,tb) = QNewRgn tb
	# (clip,tb) = QGetClip clip tb
//	# (rect,tb) = loadRgnBBox clip tb
	# (isrect,rect,tb) = osgetrgnbox clip tb
//	# tb = QClipRect (fromTuple4(l,t,r,b)) tb
	# tb = trace_n ("OSdrawBitmap: clip: "+++toString isrect+++","+++toString rect) tb
	# tb = trace_n ("OSdrawBitmap: dest: "+++toString (l,t,r,b)) tb
	# (size,tb) = GetHandleSize bitmapContents tb
	# tb = trace_n ("OSdrawBitmap: size: "+++toString size) tb

//	# tb = QPaintRect (l,t,r,b) tb
	# tb = QDrawPicture bitmapContents (l,t,r,b) tb
//	# tb = QDDrawPicture bitmapContents (l,t,r,b) tb
	# (err,tb) = QDError tb
	# tb = trace_n ("OSdrawBitmap: error",err) tb
	# tb = QDFlushPortBuffer port clip tb
	# (err,tb) = QDSetDirtyRegion port clip tb
	# tb = trace_n ("OSdrawBitmap: err0r",err) tb
	# tb = QDFlushPortBuffer port clip tb
	
	# str = createArray 64 '@'
	# tb = copy_handle_data_to_string str bitmapContents 64 tb
	# tb = trace_n ("contents",str) tb
	

//	# tb = QSetClip clip tb
	# tb = QDisposeRgn clip tb
	= (pictContext,tb)
where
	l	= px - ox
	t	= py - oy
	r	= l + w
	b	= t + h
import StdArray,pointer,StdMisc
//=====

QDDrawPicture :: !Int !(!Int,!Int,!Int,!Int) !*OSToolbox -> *OSToolbox
QDDrawPicture pic (l,t,r,b) tb
	# (ptr,err,tb)	= NewPtr 8 tb
	| err <> 0 = abort "QDDrawPicture 1"
	# tb			= StoreRect (l,t,r,b) ptr tb
	# tb			= QDDrawPicture pic ptr tb
	# (err,tb)		= QDError tb
	| err <> 0 = abort "QDDrawPicture 2"
	# tb			= DisposePtr ptr tb
	= tb
where
	QDDrawPicture :: !Int !Int !*OSToolbox -> *OSToolbox
	QDDrawPicture _ _ _ = code {
		ccall DrawPicture "II:V:I"
		}

LoadRect ptr tb
	#	(top,   tb)	= LoadWord ptr		tb
		(left,  tb)	= LoadWord (ptr+2)	tb
		(bottom,tb)	= LoadWord (ptr+4)	tb
		(right, tb)	= LoadWord (ptr+6)	tb
	=	({rleft=left,rtop=top,rright= right,rbottom=bottom},tb)

StoreRect (left,top,right,bottom) ptr tb
	#	tb	= StoreWord ptr		top		tb
		tb	= StoreWord (ptr+2)	left	tb
		tb	= StoreWord (ptr+4)	bottom	tb
		tb	= StoreWord (ptr+6)	right	tb
	=	tb

QDError :: !*OSToolbox -> (!Int,!*OSToolbox)
QDError _ = code {
	ccall QDError "P:I:I"
	}

QDFlushPortBuffer :: !Int !Int !*OSToolbox -> *OSToolbox
QDFlushPortBuffer _ _ _ = code {
	ccall QDFlushPortBuffer "II:V:I"
	}

QDSetDirtyRegion :: !Int !Int !*OSToolbox -> (!Int,!*OSToolbox)
QDSetDirtyRegion _ _ _ = code {
	ccall QDSetDirtyRegion "II:I:I"
	}

