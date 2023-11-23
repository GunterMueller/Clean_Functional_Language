implementation module LineControl

import StdControl, StdIOCommon

instance Controls LineControl where
	controlToHandles (LineControl direction width atts) pSt
		= controlToHandles impl pSt
	where
		impl			= CustomControl size look atts
		(isHor,size)	= case direction of
							Horizontal	= (True, {w=width,h=thickness})
							vertical	= (False,{w=thickness,h=width})
		thickness		= 3
		look _ _ picture
			# picture	= setPenColour Black picture
			# picture	= fill {zero & corner2={x=size.w,y=size.h}} picture
			# picture	= setPenColour White picture
			# picture	= drawAt {x=1,y=1} (if isHor {zero & vx=size.w} {zero & vy=size.w}) picture
			= picture
	getControlType _
		= "LineControl"
