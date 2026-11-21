QT += core gui qml quick quickcontrols2 network

CONFIG += c++17 release
TARGET = lightswitch
TEMPLATE = app

HEADERS += src/notes.h src/theme.h src/translator.h
SOURCES += src/main.cpp src/notes.cpp src/theme.cpp src/translator.cpp
RESOURCES += src/resources.qrc
