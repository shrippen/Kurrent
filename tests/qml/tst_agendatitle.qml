import QtQuick
import QtTest
import "../../plasmoid/com.github.shrippen.kurrent/contents/ui/components"

// AgendaTitleLabel never runs out of its column: where fitWords cannot foresee Qt's line
// breaking (a Latin word glued to Thai or to CJK punctuation), the label breaks anywhere.
TestCase {
    name: "AgendaTitleLabel"
    when: windowShown

    Component {
        id: labelComponent
        AgendaTitleLabel {
            width: 80
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }

    function test_neverOverflows_data() {
        return [
            { tag: "thai+latin", text: "ประชุมWochenplanungsbesprechung", wrap: Text.Wrap },
            { tag: "cjk punctuation", text: "Wochenplanungsbesprechung。", wrap: Text.Wrap },
            { tag: "cjk brackets", text: "会议「Wochenplanungsbesprechung」", wrap: Text.Wrap },
            { tag: "latin", text: "Wochenplanung mit dem Team", wrap: Text.WordWrap },
        ]
    }

    function test_neverOverflows(row) {
        var label = createTemporaryObject(labelComponent, this, { fullText: row.text })
        verify(label)
        tryVerify(function () { return label.contentWidth <= label.width + 0.5 }, 1000,
                  row.text + ": " + label.contentWidth + " > " + label.width)
        compare(label.wrapMode, row.wrap)
        // Breaking anywhere, the label shows the whole title, not the one cut for WordWrap.
        if (row.wrap === Text.Wrap) {
            compare(label.text, row.text)
        }
    }
}
