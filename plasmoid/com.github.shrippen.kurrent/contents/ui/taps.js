.pragma library

// What a tap on an Agenda task does. TapHandler reports every tap of a double click as
// `tapped` (tapCount 1, then 2), so a separate doubleTapped would open the editor again.
// Without the inspector the first tap opens the editor; with it the first tap inspects and
// the double click opens the editor.
function tapAction(tapCount, inspectorActive) {
    if (tapCount === 1) {
        return inspectorActive ? "inspect" : "edit"
    }
    return tapCount === 2 && inspectorActive ? "edit" : ""
}
