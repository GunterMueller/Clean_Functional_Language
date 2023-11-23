definition module xtypes;


    

:: Widget          :== Int;
:: Id              :== Int;
:: Ptr             :== Int;
:: XHandle         :== (!Id, !Widget);
:: XMenuHandle     :==  XHandle;
:: XMenuItemHandle :==  XHandle;
:: XModifier       :== Int;
:: WindowPtr       :== Int;
:: XDialogHandle   :==  XHandle;
:: XDItemHandle    :==  XHandle;


     

XNoMod          :== 0;
XCommand        :== 1;
XShift          :== 2;
XCapsLock       :== 3;
XOption         :== 4;
XControl        :== 5;

XStandardCursor :== 0;
XBusyCursor     :== 1;
XIBeamCursor    :== 2;
XCrossCursor    :== 3;
XFatCrossCursor :== 4;
XArrowCursor    :== 5;
