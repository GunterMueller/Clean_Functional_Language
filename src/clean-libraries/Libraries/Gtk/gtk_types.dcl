definition module gtk_types;

:: *GtkSt(:==Int);
:: GtkWidgetP(:==Int);

:: GValue:=={#Int}; // size 5
:: GtkTreeIter:=={#Int}; // size 4

newGtkSt :: GtkSt;
nullGtkWidgetP :: GtkWidgetP;
endGtkSt :: !GtkSt -> Int;
trueGtkSt :: !GtkSt -> (!Bool,!GtkSt);
gtk_widget_p_to_int :: !GtkWidgetP -> Int;
int_to_gtk_widget_p :: !Int -> GtkWidgetP;

