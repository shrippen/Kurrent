set(QT_DEFAULT_MAJOR_VERSION 6)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Test Qml)
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
)
target_include_directories(kurrent-models-test PRIVATE ${CMAKE_SOURCE_DIR}/plugin)
target_link_libraries(kurrent-models-test PRIVATE
    Qt6::Core
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

set(_kurrent_test_targets
    kurrent-tasklogic-test
    kurrent-sharedsettings-test
    kurrent-models-test
    kurrent-calendar-test
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
    COMMAND ${CMAKE_CTEST_COMMAND} --force-new-ctest-process --output-on-failure -C $<CONFIG> -E kurrent-plasmoidviewer
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    DEPENDS ${_kurrent_test_targets}
    COMMENT "Running Kurrent unit tests"
)
