QT += core gui testlib
CONFIG += c++17 testcase
TARGET = lightswitch_tests
TEMPLATE = app
INCLUDEPATH += ../src
HEADERS += ../src/notes.h ../src/theme.h
SOURCES += lightswitch_tests.cpp ../src/notes.cpp ../src/theme.cpp
