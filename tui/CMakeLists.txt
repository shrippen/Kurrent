# kurrent-tui: Kurrent in a terminal, on kurrentcore (ROADMAP "Terminal client").
add_executable(kurrent-tui
    main.cpp
    terminal.h
    terminal.cpp
    screens.h
    screens.cpp
    tuiapp.h
    tuiapp.cpp
)
set_target_properties(kurrent-tui PROPERTIES AUTOMOC ON)
target_link_libraries(kurrent-tui PRIVATE kurrentcore)

install(TARGETS kurrent-tui DESTINATION ${KDE_INSTALL_BINDIR})
