.pragma library

// Select the entry of a combo box whose model item has this value; leave the box as it is when
// none does. The settings pages model their boxes as arrays of { text, value }.
function selectByValue(combo, value) {
    for (var i = 0; i < combo.model.length; ++i) {
        if (combo.model[i].value === value) {
            combo.currentIndex = i
            return
        }
    }
}
