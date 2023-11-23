implementation module gtk_types;

:: *GtkSt:==Int;
:: GtkWidgetP:==Int;

:: GValue:=={#Int}; // size 5
:: GtkTreeIter:=={#Int}; // size 4

newGtkSt :: GtkSt;
newGtkSt = 0;

nullGtkWidgetP :: GtkWidgetP;
nullGtkWidgetP = 0;

endGtkSt :: !GtkSt -> Int;
endGtkSt gs = 0;

trueGtkSt :: !GtkSt -> (!Bool,!GtkSt);
trueGtkSt gs = (True,gs);

gtk_widget_p_to_int :: !GtkWidgetP -> Int;
gtk_widget_p_to_int gwp = gwp;

int_to_gtk_widget_p :: !Int -> GtkWidgetP;
int_to_gtk_widget_p gwp = gwp;
