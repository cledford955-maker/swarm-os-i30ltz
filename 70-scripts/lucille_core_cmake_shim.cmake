# Included via CMAKE_PROJECT_lucille_core_INCLUDE by build_swarm_iso.sh.
# lucille-core links SQLite3::SQLite3, but CMake's FindSQLite3 only defines
# SQLite::SQLite3. Alias it here so lucille-core's CMakeLists stays untouched.
find_package(SQLite3 REQUIRED)
if(NOT TARGET SQLite3::SQLite3)
    add_library(SQLite3::SQLite3 INTERFACE IMPORTED)
    target_link_libraries(SQLite3::SQLite3 INTERFACE SQLite::SQLite3)
endif()
