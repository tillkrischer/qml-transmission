cmake_minimum_required(VERSION 3.21)

project(qml-transmission VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Concurrent Test)
find_package(Qt6Keychain REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

qt_add_executable(qml-transmission
    src/main.cpp
    src/CredentialStore.cpp src/CredentialStore.h
    src/TorrentFileReader.cpp src/TorrentFileReader.h
)

qt_add_qml_module(qml-transmission
    URI QmlTransmission
    VERSION 1.0
    QML_FILES
        Main.qml TransmissionClient.qml TorrentStore.qml TorrentList.qml
        TorrentDetails.qml ConnectionDialog.qml ConnectionProfiles.qml
        AddTorrentDialog.qml AddTorrentController.qml StatusIcon.qml
        TorrentFilesStore.qml TorrentFilesView.qml
        js/Format.js js/RpcProtocol.js js/FileTree.js
    RESOURCES
        icons/add.svg icons/start.svg icons/stop.svg icons/remove.svg
        icons/connect.svg icons/disconnect.svg icons/profiles.svg
)

target_link_libraries(qml-transmission PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Concurrent
    Qt6Keychain::Qt6Keychain
)

install(TARGETS qml-transmission RUNTIME DESTINATION bin)

include(CTest)
if(BUILD_TESTING)
    qt_add_executable(tst_native
        tests/tst_native.cpp
        src/TorrentFileReader.cpp src/TorrentFileReader.h
    )
    target_include_directories(tst_native PRIVATE src)
    target_link_libraries(tst_native PRIVATE Qt6::Core Qt6::Concurrent Qt6::Test)
    add_test(NAME native COMMAND tst_native)
endif()
