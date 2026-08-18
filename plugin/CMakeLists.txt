set(QT_DEFAULT_MAJOR_VERSION 6)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml DBus)
find_package(KF6 REQUIRED COMPONENTS CalendarCore I18n Config)
find_package(KF6 QUIET COMPONENTS Notifications GlobalAccel)
find_package(KPim6Akonadi REQUIRED)

add_library(kurrentplugin SHARED
    kurrentplugin.cpp
    taskcontroller.cpp
    taskcontroller.h
    tasklogic.cpp
    tasklogic.h
    taskcalendar.cpp
    taskcalendar.h
    tasklistmodel.cpp
    tasklistmodel.h
    collectionlistmodel.cpp
    collectionlistmodel.h
    sharedsettings.cpp
    sharedsettings.h
    kurrentdbus.cpp
    kurrentdbus.h
)

set_target_properties(kurrentplugin PROPERTIES
    AUTOMOC ON
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/com/github/shrippen/kurrent"
)

target_link_libraries(kurrentplugin PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::DBus
    KF6::CalendarCore
    KF6::I18n
    KF6::ConfigCore
    KPim6::AkonadiCore
)

if(TARGET KF6::Notifications)
    target_link_libraries(kurrentplugin PRIVATE KF6::Notifications)
    target_compile_definitions(kurrentplugin PRIVATE KURRENT_HAS_NOTIFICATIONS=1)
endif()

if(TARGET KF6::GlobalAccel)
    target_link_libraries(kurrentplugin PRIVATE KF6::GlobalAccel)
    target_compile_definitions(kurrentplugin PRIVATE KURRENT_HAS_GLOBALACCEL=1)
endif()

# Prefer Qt's QML dir; fall back to lib/qml under the install prefix.
if(NOT KDE_INSTALL_QMLDIR OR KDE_INSTALL_QMLDIR STREQUAL "")
    set(KDE_INSTALL_QMLDIR "lib/qml")
endif()

set(QML_PLUGIN_DEST "${KDE_INSTALL_QMLDIR}/com/github/shrippen/kurrent")

install(TARGETS kurrentplugin DESTINATION ${QML_PLUGIN_DEST})
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/qmldir DESTINATION ${QML_PLUGIN_DEST})

# Also install under share/qt6/qml — some Plasma/Qt setups prefer this path.
install(TARGETS kurrentplugin DESTINATION "share/qt6/qml/com/github/shrippen/kurrent")
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/qmldir DESTINATION "share/qt6/qml/com/github/shrippen/kurrent")
