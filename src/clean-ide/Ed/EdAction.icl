implementation module EdAction

import StdInt, StdArray, StdTuple, StdBool, StdChar, StdList, StdMisc
import StdIOCommon, StdPSt, StdWindow
import EdVisualCursor, EdVisualText, EdMovement, StrictList, EdMonad
import EdActionType, EdSelection

import EdCommon

performAction :: Action -> EditMonad (PSt PLocState) nothing
performAction action =
        // things to do before the action is applied
        undoStuff action									>>>
		vHideCursor											>>>
        onlyIf (needsCenterCursor action) 
                vCenterCursor								>>>
        getSelection										>>>= \selection ->
        onlyIf (needsResetVirtualX action selection)
                ( setVirtualX 0 )							>>>
        onlyIf (needsRemoveSelection action)
                removeSelectionIfNecessary					>>>= \selectionRemoved ->
        // apply the action
        applyAction selectionRemoved action					>>>
        vShowCursor

applyAction :: Bool Action -> EditMonad (PSt PLocState) nothing
applyAction selectionRemoved action =
        case action of

          // Move actions are performed in the following way. If there is a selection,
          // the cursor moves to the start or end of the selection. Otherwise, the
          // new position is computed by "positionAfterMove". After moving the cursor,
          // the selection is emptied and hidden.
         
          Move move ->
                getSelection                                  >>>= \selection ->
                IF (selection.start == selection.end)
                THEN
                  ( positionAfterMove move selection.start          >>>= \newPos ->
	                vChangeSelectionTo {start=newPos,end=newPos}	>>>
// DvA: can skip this as we know we are going from no selection to no selection...
//	                mChangeSelectionTo {start=newPos,end=newPos}	>>>
					IF (move == PageUp || move == PageDown)
					THEN
						(vMoveCursor move)
					ELSE
						vScrollToCursor
				  )
                ELSE 
                  (
                      ( if (isMember move [CharLeft,WordLeft,PageUp,LineUp,StartOfLine])
                                    (result (orderSelection selection).start)
                                    (case move of
                                    	StartOfText	-> positionAfterMove move selection.start
                                    	EndOfText	-> positionAfterMove move selection.start
                                    	_			-> result (orderSelection selection).end
                                    )
                      )                                             >>>= \newPos ->
	                vChangeSelectionTo {start=newPos,end=newPos}	>>>
// DvA: we know we are going from selection to no selection so...
//	                mChangeSelectionTo {start=newPos,end=newPos}	>>>
					mRemoveSelection								>>>
					vScrollToCursor
                  )

          // The insert action is mainly done by "vInsertText". It inserts the
          // text into the internal representation and then redraws as much of
          // the screen as is necessary. After inserting the text, the cursor
          // is position behind that text.
          
          Insert fragment ->
            getSelection                                  >>>= \selection ->
            let newPos = positionAfterText selection.start fragment
            in
            vInsertText selection.start fragment            >>>
            vChangeSelectionTo {start=newPos,end=newPos}    >>> 
            mChangeSelectionTo {start=newPos,end=newPos}    >>>
			vScrollToCursor									>>>
            setNeedSave True

          // Scrolling has no effect on the cursor position. It just 
          // changes which part of the whole view domain is visible.
          
          Scroll move ->
                getFontInfo                                  >>>= \{lineHeight} ->
                getText                                      >>>= \text ->
                getWindowId                                  >>>= \windowId ->
                accEnv (accPIO (getWindowViewFrame windowId))>>>= \frame ->
                let
                	linesInFrame        = (frame.corner2.y - frame.corner1.y) / lineHeight
                    pagePixels          = (linesInFrame - 1) * lineHeight 
                    topPixel			= 0
                    botPixel			= textLength text * lineHeight
                    newTopPixel         = case move of
                                            PageUp          -> max topPixel (frame.corner1.y - pagePixels)
                                            PageDown        -> min botPixel (frame.corner1.y + pagePixels)
                                            StartOfText     -> topPixel
                                            EndOfText       -> botPixel - pagePixels
                                            _				-> frame.corner1.y	// if unknown -> ignore
 
                in
                appEnv (appPIO (moveWindowViewFrame windowId {vx=0, vy=newTopPixel-frame.corner1.y}))
 
          // A select action changes the current selection if there is any and
          // otherwise starts a new one.
          
          Select move ->
			getSelection                                            >>>= \selection ->
			positionAfterMove move selection.end                    >>>= \newPos ->
			let selectionStart = selection.start
			in
			vChangeSelectionTo {start=selectionStart,end=newPos}	>>>
			mChangeSelectionTo {start=selectionStart,end=newPos}	>>>
			vScrollToCursor									

          // A remove action has to remove the selection if there is any. This
          // has already been done by the 'preprocessing' in "performAction".
          // If that preprocessing has removed the selection, nothing has to
          // be done here. Otherwise, the position after the movement is computed
          // and every character from the original position to the new one is
          // removed.
          
          Remove move ->
                setNeedSave True                                >>>
            IF selectionRemoved
            THEN skip
            ELSE
              (
                getSelection									>>>= \{start} ->
                positionAfterMove move start                    >>>= \newPos ->
                setSelection {start=start,end=newPos}           >>>
                vRemoveSelection								>>>
				mRemoveSelection
              )													>>>
			vScrollToCursor									
              

          _ ->
                abort "applyAction (EdAction.icl): unknown action"

where
        positionAfterText :: !Position !TextFragment -> Position
        positionAfterText position SNil = position
        positionAfterText {col, row} (SCons string SNil)
          = {col=col+size string, row=row}
        positionAfterText {row} strings
          = {col=size (slLast strings), row=row+slLength strings-1}


// The "needs..." functions specify whether certain actions
// need certain preprocessing or postprocessing.
 
needsCenterCursor :: Action -> Bool
needsCenterCursor (Scroll _)    = False
needsCenterCursor _             = True

needsRemoveSelection :: Action -> Bool
needsRemoveSelection (Remove _) = True
needsRemoveSelection (Insert _) = True
needsRemoveSelection _                  = False

needsResetVirtualX :: Action Selection -> Bool
needsResetVirtualX (Scroll _) _ = False
needsResetVirtualX (Move move) selection
  | isVerticalMove move
    = not (isEmptySelection selection)
    = True
needsResetVirtualX (Select move) _
  = not (isVerticalMove move)
needsResetVirtualX _ _ = True

// removeSelectionIfNecessary removes the selection if there
// is any. It also results a boolean to indicate whether removal
// was necessary.

removeSelectionIfNecessary :: EditMonad (PSt PLocState) Bool
removeSelectionIfNecessary
  = getSelection                                                >>>= \selection ->
        IF (not (isEmptySelection selection))
        THEN
          (
                vRemoveSelection                                >>>
 				mRemoveSelection								>>>
                result True
          )
        ELSE
          ( result False )

undoStuff :: !Action -> EditMonad (PSt .l) nothing
undoStuff (Insert _) =
        getUndoInfo                                     >>>= \undoinfo ->
        case undoinfo.uninfo of
        (InsertInfo True _) -> skip
        _ ->
                getState                                >>>= \state ->
                setUndoInfo {state=Undo,action=" Typing",uninfo=(InsertInfo True state)}
undoStuff (Remove _) =
        getUndoInfo                                     >>>= \undoinfo ->
        case undoinfo.uninfo of
        (RemoveInfo True _) -> skip
        _ ->
                getState                                >>>= \state ->
                setUndoInfo {state=Undo,action=" Deletion",uninfo=(RemoveInfo True state)}
undoStuff _ =
        getUndoInfo                                     >>>= \undoinfo ->
        case undoinfo.uninfo of
        (InsertInfo True state) -> setUndoInfo {undoinfo & uninfo=(InsertInfo False state)}
        (RemoveInfo True state) -> setUndoInfo {undoinfo & uninfo=(RemoveInfo False state)}
        _ -> skip

undoAction :: EditMonad (PSt .l) nothing
undoAction =
        getUndoInfo                                     >>>= \undoinfo ->
        getState                                        >>>= \fin ->
        case undoinfo.uninfo of
        (InsertInfo _ ini) -> setUndoInfo {undoinfo & uninfo=(UndoneInfo ini fin)}
        (RemoveInfo _ ini) -> setUndoInfo {undoinfo & uninfo=(UndoneInfo ini fin)}
        _ -> skip
