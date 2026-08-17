#!/bin/sh
# Extract translatable strings from QML and C++ sources.
# Catalog name must match the Plasma applet id prefix plasma_applet_<Id>.
$XGETTEXT `find plasmoid plugin -name '*.qml' -o -name '*.cpp' -o -name '*.h' -o -name '*.js'` \
    -o "$podir/plasma_applet_com.github.shrippen.kurrent.pot"
