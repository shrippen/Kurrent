find_package(Qt6 REQUIRED COMPONENTS DBus Gui)
find_package(KF6 REQUIRED COMPONENTS Runner I18n)

add_library(kurrentrunner MODULE kurrentrunner.cpp)

target_link_libraries(kurrentrunner PRIVATE
    KF6::Runner
    KF6::I18n
    Qt6::DBus
    Qt6::Gui
)

set_target_properties(kurrentrunner PROPERTIES
    AUTOMOC ON
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib/kf6/krunner"
)

install(TARGETS kurrentrunner DESTINATION ${KDE_INSTALL_PLUGINDIR}/kf6/krunner)
install(FILES kurrentrunner.json DESTINATION ${KDE_INSTALL_DATADIR}/krunner)
