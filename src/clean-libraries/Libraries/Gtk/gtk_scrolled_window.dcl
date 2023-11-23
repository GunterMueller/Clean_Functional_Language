definition module gtk_scrolled_window;

import gtk_types;

GTK_POLICY_AUTOMATIC:==1;

:: GtkPolicyType:==Int;

gtk_scrolled_window_new :: !GtkWidgetP !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_scrolled_window_set_policy :: !GtkWidgetP !GtkPolicyType !GtkPolicyType !GtkSt -> GtkSt;
gtk_scrolled_window_add_with_viewport :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
gtk_scrolled_window_get_hadjustment :: !GtkWidgetP ! GtkSt -> (!GtkWidgetP,!GtkSt);

