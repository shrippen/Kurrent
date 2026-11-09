set(QT_DEFAULT_MAJOR_VERSION 6)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Test Qml Concurrent)
find_package(KF6 REQUIRED COMPONENTS CalendarCore Config)
find_package(KPim6Akonadi REQUIRED)

set(CMAKE_AUTOMOC ON)

add_executable(kurrent-tasklogic-test
    tasklogic_test.cpp
    ${CMAKE_SOURCE_DIR}/plugin/tasklogic.cpp
    ${CMAKE_SOURCE_DIR}/plugin/tasklogic.h
    ${CMAKE_SOURCE_DIR}/plugin/quickadd.cpp
)
target_include_directories(kurrent-tasklogic-test PRIVATE ${CMAKE_SOURCE_DIR}/plugin)
target_link_libraries(kurrent-tasklogic-test PRIVATE Qt6::Core Qt6::Gui Qt6::Test)
add_test(NAME kurrent-tasklogic COMMAND kurrent-tasklogic-test)

add_executable(kurrent-agendalogic-test
    agendalogic_test.cpp
    ${CMAKE_SOURCE_DIR}/plugin/agendalogic.cpp
    ${CMAKE_SOURCE_DIR}/plugin/agendalogic.h
    ${CMAKE_SOURCE_DIR}/plugin/tasklogic.cpp
    ${CMAKE_SOURCE_DIR}/plugin/quickadd.cpp
)
target_include_directories(kurrent-agendalogic-test PRIVATE ${CMAKE_SOURCE_DIR}/plugin)
target_link_libraries(kurrent-agendalogic-test PRIVATE Qt6::Core Qt6::Gui Qt6::Test)
add_test(NAME kurrent-agendalogic COMMAND kurrent-agendalogic-test)

add_executable(kurrent-sharedsettings-test
    sharedsettings_test.cpp
    ${CMAKE_SOURCE_DIR}/plugin/sharedsettings.cpp
    ${CMAKE_SOURCE_DIR}/plugin/sharedsettings.h
)
target_include_directories(kurrent-sharedsettings-test PRIVATE ${CMAKE_SOURCE_DIR}/plugin)
target_link_libraries(kurrent-sharedsettings-test PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Test
    KF6::ConfigCore
)
add_test(NAME kurrent-sharedsettings COMMAND kurrent-sharedsettings-test)

add_executable(kurrent-models-test
    models_test.cpp
    ${CMAKE_SOURCE_DIR}/plugin/tasklistmodel.cpp
    ${CMAKE_SOURCE_DIR}/plugin/tasklistmodel.h
    ${CMAKE_SOURCE_DIR}/plugin/collectionlistmodel.cpp
    ${CMAKE_SOURCE_DIR}/plugin/collectionlistmodel.h
    ${CMAKE_SOURCE_DIR}/plugin/tasklogic.cpp
    ${CMAKE_SOURCE_DIR}/plugin/quickadd.cpp
)
target_include_directories(kurrent-models-test PRIVATE ${CMAKE_SOURCE_DIR}/plugin)
target_link_libraries(kurrent-models-test PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Test
    KPim6::AkonadiCore
)
add_test(NAME kurrent-models COMMAND kurrent-models-test)

add_executable(kurrent-calendar-test
    calendar_test.cpp
    ${CMAKE_SOURCE_DIR}/plugin/taskcalendar.cpp
    ${CMAKE_SOURCE_DIR}/plugin/taskcalendar.h
)
target_include_directories(kurrent-calendar-test PRIVATE ${CMAKE_SOURCE_DIR}/plugin)
target_link_libraries(kurrent-calendar-test PRIVATE
    Qt6::Core
    Qt6::Test
    KF6::CalendarCore
)
add_test(NAME kurrent-calendar COMMAND kurrent-calendar-test)

add_executable(kurrent-tui-screens-test
    tui_screens_test.cpp
    ${CMAKE_SOURCE_DIR}/tui/screens.cpp
    ${CMAKE_SOURCE_DIR}/tui/screens.h
)
target_include_directories(kurrent-tui-screens-test PRIVATE ${CMAKE_SOURCE_DIR}/tui)
target_link_libraries(kurrent-tui-screens-test PRIVATE Qt6::Core Qt6::Test)
add_test(NAME kurrent-tui-screens COMMAND kurrent-tui-screens-test)

add_executable(kurrent-taskstore-test
    taskstore_test.cpp
    ${CMAKE_SOURCE_DIR}/plugin/memorytaskstore.cpp
    ${CMAKE_SOURCE_DIR}/plugin/memorytaskstore.h
    ${CMAKE_SOURCE_DIR}/plugin/taskstore.h
)
target_include_directories(kurrent-taskstore-test PRIVATE ${CMAKE_SOURCE_DIR}/plugin)
target_link_libraries(kurrent-taskstore-test PRIVATE
    Qt6::Core
    Qt6::Test
    KF6::CalendarCore
    KPim6::AkonadiCore
)
add_test(NAME kurrent-taskstore COMMAND kurrent-taskstore-test)
set_tests_properties(kurrent-taskstore PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

# TaskController + MemoryTaskStore: compile sources into the test binary because
# kurrentplugin hides symbols (-fvisibility=hidden).
find_package(KF6 REQUIRED COMPONENTS I18n)
add_executable(kurrent-taskcontroller-store-test
    taskcontroller_store_test.cpp
    ${CMAKE_SOURCE_DIR}/plugin/taskcontroller.cpp
    ${CMAKE_SOURCE_DIR}/plugin/agendalogic.cpp
    ${CMAKE_SOURCE_DIR}/plugin/tasklogic.cpp
    ${CMAKE_SOURCE_DIR}/plugin/quickadd.cpp
    ${CMAKE_SOURCE_DIR}/plugin/taskcalendar.cpp
    ${CMAKE_SOURCE_DIR}/plugin/tasklistmodel.cpp
    ${CMAKE_SOURCE_DIR}/plugin/collectionlistmodel.cpp
    ${CMAKE_SOURCE_DIR}/plugin/sharedsettings.cpp
    ${CMAKE_SOURCE_DIR}/plugin/kurrentdbus.cpp
    ${CMAKE_SOURCE_DIR}/plugin/memorytaskstore.cpp
    ${CMAKE_SOURCE_DIR}/plugin/akonaditaskstore.cpp
    ${CMAKE_SOURCE_DIR}/plugin/kurrentlogging.cpp
    ${CMAKE_SOURCE_DIR}/plugin/demodata.cpp
    ${CMAKE_SOURCE_DIR}/plugin/taskstore.h
)
target_compile_definitions(kurrent-taskcontroller-store-test PRIVATE
    # Same catalog as kurrentcore (plugin/CMakeLists.txt); undoLabelIsTranslated reads it.
    TRANSLATION_DOMAIN="plasma_applet_com.github.shrippen.kurrent"
    KURRENT_TEST_LOCALE_DIR="${CMAKE_BINARY_DIR}/locale"
    KURRENT_WITH_DEMO
    KURRENT_TEST_DEMO_WORLD="${CMAKE_SOURCE_DIR}/demo/world.json")
target_include_directories(kurrent-taskcontroller-store-test PRIVATE ${CMAKE_SOURCE_DIR}/plugin)
target_link_libraries(kurrent-taskcontroller-store-test PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::DBus
    Qt6::Concurrent
    Qt6::Test
    KF6::CalendarCore
    KF6::I18n
    KF6::ConfigCore
    KPim6::AkonadiCore
)
# Expected TaskController::devBuild() for this configuration (#33).
if(KURRENT_DEV_BUILD)
    set(_kurrent_expect_dev 1)
    set(_kurrent_expect_dev_qml true)
else()
    set(_kurrent_expect_dev 0)
    set(_kurrent_expect_dev_qml false)
endif()
target_compile_definitions(kurrent-taskcontroller-store-test PRIVATE
    KURRENT_TEST_EXPECT_DEV_BUILD=${_kurrent_expect_dev})
add_test(NAME kurrent-taskcontroller-store COMMAND kurrent-taskcontroller-store-test)
if(TARGET kurrent-translations)
    add_dependencies(kurrent-taskcontroller-store-test kurrent-translations)
endif()
add_test(NAME kurrent-devbuild-marker
    COMMAND ${CMAKE_COMMAND} -DMARKER=${CMAKE_BINARY_DIR}/DevBuildMarker.qml
            -DEXPECTED=${_kurrent_expect_dev_qml} -P ${CMAKE_CURRENT_SOURCE_DIR}/check_devbuild_marker.cmake)
set_tests_properties(kurrent-taskcontroller-store PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

# Performance benchmark (tests/perf_bench.cpp); not run by ctest.
option(KURRENT_BUILD_BENCH "Build the task-list performance benchmark" OFF)
if(KURRENT_BUILD_BENCH)
    add_executable(kurrent-perf-bench
        perf_bench.cpp
        ${CMAKE_SOURCE_DIR}/plugin/taskcontroller.cpp
        ${CMAKE_SOURCE_DIR}/plugin/agendalogic.cpp
        ${CMAKE_SOURCE_DIR}/plugin/tasklogic.cpp
        ${CMAKE_SOURCE_DIR}/plugin/quickadd.cpp
        ${CMAKE_SOURCE_DIR}/plugin/taskcalendar.cpp
        ${CMAKE_SOURCE_DIR}/plugin/tasklistmodel.cpp
        ${CMAKE_SOURCE_DIR}/plugin/collectionlistmodel.cpp
        ${CMAKE_SOURCE_DIR}/plugin/sharedsettings.cpp
        ${CMAKE_SOURCE_DIR}/plugin/kurrentdbus.cpp
        ${CMAKE_SOURCE_DIR}/plugin/memorytaskstore.cpp
        ${CMAKE_SOURCE_DIR}/plugin/akonaditaskstore.cpp
        ${CMAKE_SOURCE_DIR}/plugin/kurrentlogging.cpp
        ${CMAKE_SOURCE_DIR}/plugin/demodata.cpp
        ${CMAKE_SOURCE_DIR}/plugin/taskstore.h
    )
    target_include_directories(kurrent-perf-bench PRIVATE ${CMAKE_SOURCE_DIR}/plugin)
    target_link_libraries(kurrent-perf-bench PRIVATE
        Qt6::Core Qt6::Gui Qt6::Qml Qt6::DBus Qt6::Concurrent Qt6::Test
        KF6::CalendarCore KF6::I18n KF6::ConfigCore KPim6::AkonadiCore)
endif()

set(_kurrent_test_targets
    kurrent-tasklogic-test
    kurrent-agendalogic-test
    kurrent-sharedsettings-test
    kurrent-models-test
    kurrent-calendar-test
    kurrent-taskstore-test
    kurrent-taskcontroller-store-test
    kurrent-tui-screens-test
)

find_package(Qt6 COMPONENTS QuickTest Qml Quick)
if(TARGET Qt6::QuickTest AND TARGET Qt6::Qml AND TARGET Qt6::Quick)
    add_executable(kurrent-qml-test qmltest.cpp)
    target_link_libraries(kurrent-qml-test PRIVATE Qt6::QuickTest Qt6::Qml Qt6::Quick)
    target_compile_definitions(kurrent-qml-test PRIVATE
        QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml"
    )
    add_test(NAME kurrent-qml COMMAND kurrent-qml-test)
    set_tests_properties(kurrent-qml PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
    )
    list(APPEND _kurrent_test_targets kurrent-qml-test)
endif()

add_test(NAME kurrent-plasmoidviewer
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/plasmoidviewer_smoke.sh"
)
set_tests_properties(kurrent-plasmoidviewer PROPERTIES
    SKIP_RETURN_CODE 77
)

add_custom_target(kurrent-check ALL
    # -C only with a configuration: without CMAKE_BUILD_TYPE "-C" would get no value and fail.
    COMMAND ${CMAKE_CTEST_COMMAND} --force-new-ctest-process --output-on-failure
            "$<$<BOOL:$<CONFIG>>:-C;$<CONFIG>>" -E kurrent-plasmoidviewer
    COMMAND_EXPAND_LISTS
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    DEPENDS ${_kurrent_test_targets}
    COMMENT "Running Kurrent unit tests"
)
