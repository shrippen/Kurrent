import QtQuick
import QtTest
import "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/components"

// "Reset this page" sets each listed key to the page's cfg_<name>Default, which Plasma fills from
// main.xml; keys the button does not list stay as they are.
TestCase {
    name: "ConfigResetButton"
    width: 300; height: 100
    when: windowShown

    Item {
        id: page
        property string cfg_mode: "custom"
        property string cfg_modeDefault: "auto"
        property int cfg_size: 20
        property int cfg_sizeDefault: 10
        property bool cfg_flag: true
        property bool cfg_flagDefault: false
        property int cfg_other: 5
        property int cfg_otherDefault: 1
        property int synced: 0
        function syncControls() { synced++ }
    }

    ConfigResetButton {
        id: button
        page: page
        keys: ["mode", "size", "flag"]
    }

    function test_resetsListedKeysToDefaults() {
        button.clicked()
        compare(page.cfg_mode, "auto")
        compare(page.cfg_size, 10)
        compare(page.cfg_flag, false)
        compare(page.cfg_other, 5)
        compare(page.synced, 1)
    }
}
