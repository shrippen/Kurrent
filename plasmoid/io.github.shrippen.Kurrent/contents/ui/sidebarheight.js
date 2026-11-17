.pragma library

// Height distribution of the sidebar sections, in pixels. The sections are the lists
// "views", "projects", "labels" and so on, stacked in a column of limited height.

// Height of a list with `rowCount` rows, an optional header and 1 px between the parts.
function naturalListHeight(rowCount, hasHeader, headerHeight, rowHeight) {
    var rows = Math.max(0, rowCount)
    var header = hasHeader ? headerHeight : 0
    var parts = rows + (hasHeader ? 1 : 0)
    var gaps = Math.max(0, parts - 1)
    return header + rows * rowHeight + gaps
}

// Smallest height a visible section is cut down to: one row below its header.
function floorHeight(hasHeader, headerHeight, rowHeight) {
    var header = hasHeader ? headerHeight : 0
    return Math.max(1, header + rowHeight + 1)
}

// The height of each section in a column of `available` pixels. `naturals`, `visibleFlags`
// and `hasHeader` hold one entry per section. Hidden sections get 0. Returns null when no
// section is visible.
function distribute(available, naturals, visibleFlags, hasHeader, headerHeight, rowHeight) {
    var sectionCount = naturals.length
    var visibleCount = 0
    var sumNatural = 0
    for (var s = 0; s < sectionCount; ++s) {
        if (visibleFlags[s]) {
            ++visibleCount
            sumNatural += naturals[s]
        }
    }
    if (visibleCount <= 0) {
        return null
    }

    var viewsPinned = false
    var alloc = []
    for (var z = 0; z < sectionCount; ++z) {
        alloc.push(0)
    }
    // Slack is only for scrollbar visibility (Design.listNeedsScroll), not allocation —
    // otherwise resizing feels sticky near the fit boundary then jumps.
    if (sumNatural <= available) {
        var leftover = available - sumNatural
        var evenGrow = Math.floor(leftover / visibleCount)
        var extraGrow = leftover - evenGrow * visibleCount
        for (var i = 0; i < sectionCount; ++i) {
            if (!visibleFlags[i]) {
                continue
            }
            alloc[i] = naturals[i] + evenGrow + (extraGrow > 0 ? 1 : 0)
            if (extraGrow > 0) {
                extraGrow--
            }
        }
    } else {
        // Short widget: keep relative content sizes (not equal floors).
        var mins = []
        var sumMins = 0
        for (var m = 0; m < sectionCount; ++m) {
            var floorH = visibleFlags[m] ? floorHeight(hasHeader[m], headerHeight, rowHeight) : 0
            mins.push(floorH)
            sumMins += floorH
        }

        // The views are a short, fixed list that is always needed: they keep their full
        // height while the other sections still fit at their floors, and those scroll.
        if (visibleFlags[0] && sumMins - mins[0] + naturals[0] <= available) {
            sumMins += naturals[0] - mins[0]
            mins[0] = naturals[0]
            viewsPinned = true
        }

        if (sumMins >= available) {
            for (var mc = 0; mc < sectionCount; ++mc) {
                alloc[mc] = mins[mc]
            }
            var over = sumMins - available
            if (over > 0) {
                for (var t = 0; t < sectionCount && over > 0; ++t) {
                    if (!visibleFlags[t]) {
                        continue
                    }
                    var cut = Math.min(over, Math.max(0, alloc[t] - 1))
                    alloc[t] -= cut
                    over -= cut
                }
            }
        } else {
            var flex = available - sumMins
            var flexNatural = 0
            for (var f = 0; f < sectionCount; ++f) {
                if (visibleFlags[f]) {
                    flexNatural += Math.max(0, naturals[f] - mins[f])
                }
            }
            var remain = flex
            for (var p = 0; p < sectionCount; ++p) {
                if (!visibleFlags[p]) {
                    continue
                }
                var extraNeed = Math.max(0, naturals[p] - mins[p])
                var share = (flexNatural > 0)
                    ? Math.floor(flex * extraNeed / flexNatural)
                    : Math.floor(flex / visibleCount)
                alloc[p] = mins[p] + share
                remain -= share
            }
            for (var r = 0; r < sectionCount && remain > 0; ++r) {
                if (visibleFlags[r]) {
                    alloc[r] += 1
                    remain--
                }
            }
        }
    }

    // Near-fit: if a section is short by at most one row, give it full natural
    // height by stealing from sections that still overflow by more than one row.
    var oneRow = rowHeight + 1
    for (var g = 0; g < sectionCount; ++g) {
        if (!visibleFlags[g]) {
            continue
        }
        var shortfall = naturals[g] - alloc[g]
        if (shortfall <= 0 || shortfall > oneRow) {
            continue
        }
        var need = shortfall
        for (var donor = 0; donor < sectionCount && need > 0; ++donor) {
            if (!visibleFlags[donor] || donor === g || (donor === 0 && viewsPinned)) {
                continue
            }
            var donorOverflow = naturals[donor] - alloc[donor]
            var floorH = floorHeight(hasHeader[donor], headerHeight, rowHeight)
            var spare = Math.max(0, alloc[donor] - floorH)
            // Prefer donors that must scroll anyway (more than one row short).
            if (donorOverflow <= oneRow && spare <= 0) {
                continue
            }
            var take = Math.min(need, spare)
            if (take <= 0) {
                continue
            }
            alloc[donor] -= take
            need -= take
        }
        if (need === 0) {
            alloc[g] = naturals[g]
        }
    }

    return alloc
}
