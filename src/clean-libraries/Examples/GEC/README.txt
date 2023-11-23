README

The example programs in this folder show what GECs can do. The source code does not contain any comments, so you might be scared off by what you see, but please try. If you wonder what a certain example is supposed to demonstrate, you'll have to study the GEC-related papers on the Clean site.


Before you start experimenting with the demo's, a few notes on known issues:

1) If in a demo you are required to key in a Real number, you'll have to make sure you type 
in a valid Real, i.e. including a decimal point. 
The program won't give you an error message when you type an invalid Real. 
It will just reset the field to the previous value. Similar requirements hold for other types.

2) If you have typed in a valid Real, you'll have to make sure the cursor does not end up 
somewhere in the middle of the value you typed in, because the parser fails 
if there is anything to the right of the cursor. Similar requirements hold for other types.

3) A demo may actually turn a valid Real into an invalid one. 
That happens when you type in a negative Real that happens to be a whole number, e.g. -67.0
The program drops everything from the decimal point onward, so it becomes -67


Items 2) and 3) have nothing to do with the GEC-library itself, 
but result from limitations of the used parse and print routines in the Object I/O-library. 
Item 1) is a GEC issue. Error messages, Item 1), 
actually deserve a better treatment in the GEC library. 
Needless to say it is future work to solve these issues, 
but we cannot say when that will be. 
For now, we hope the notes above will get you across the first few hurdles and 
that you'll learn to appreciate the concise formulation of GUI's the GEC way.

   