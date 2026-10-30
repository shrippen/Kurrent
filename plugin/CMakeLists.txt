set(QT_DEFAULT_MAJOR_VERSION 6)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml DBus Concurrent)
find_package(KF6 REQUIRED COMPONENTS CalendarCore I18n Config)
find_package(KF6 QUIET COMPONENTS Notifications GlobalAccel)
find_package(KPim6Akonadi REQUIRED)

# kurrentcore: tasks, Quick Add, Akonadi store, controller. No QML types are
# registered here, so the plugin and the terminal client (tui/) both link it.
#
#   kurrentplugin (QML: main.qml, views) ─┐
#   kurrent-tui   (terminal)             ─┴─▶ kurrentcore ─▶ Akonadi / KCalendarCore
add_library(kurrentcore STATIC
    taskcontroller.cpp
    taskcontroller.h
    tasklogic.cpp
    tasklogic.h
    agendalogic.cpp
    agendalogic.h
    quickadd.cpp
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
    kurrentlogging.h
    kurrentlogging.cpp
    taskstore.h
    akonaditaskstore.cpp
    akonaditaskstore.h
    memorytaskstore.cpp
    memorytaskstore.h
)

# Internal demo mode for the landing-page screenshots (demo/). Never on in releases.
option(KURRENT_DEMO "Internal demo mode for screenshots; never enable for releases" OFF)
if(KURRENT_DEMO)
    target_sources(kurrentcore PRIVATE demodata.cpp demodata.h)
    target_compile_definitions(kurrentcore PRIVATE KURRENT_WITH_DEMO)
endif()

set_target_properties(kurrentcore PROPERTIES
    AUTOMOC ON
    POSITION_INDEPENDENT_CODE ON
)
target_include_directories(kurrentcore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(kurrentcore PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::DBus
    Qt6::Concurrent
    KF6::CalendarCore
    KF6::I18n
    KF6::ConfigCore
    KPim6::AkonadiCore
)

if(TARGET KF6::Notifications)
    target_link_libraries(kurrentcore PUBLIC KF6::Notifications)
    target_compile_definitions(kurrentcore PRIVATE KURRENT_HAS_NOTIFICATIONS=1)
endif()

if(TARGET KF6::GlobalAccel)
    target_link_libraries(kurrentcore PUBLIC KF6::GlobalAccel)
    target_compile_definitions(kurrentcore PRIVATE KURRENT_HAS_GLOBALACCEL=1)
endif()

add_library(kurrentplugin SHARED
    kurrentplugin.cpp
)

set_target_properties(kurrentplugin PROPERTIES
    AUTOMOC ON
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/com/github/shrippen/kurrent"
)

target_link_libraries(kurrentplugin PRIVATE kurrentcore)

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
