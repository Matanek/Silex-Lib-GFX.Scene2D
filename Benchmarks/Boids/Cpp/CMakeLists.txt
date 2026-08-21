cmake_minimum_required(VERSION 3.28)

project(BoidsCppSDL LANGUAGES CXX)

find_package(SDL3 CONFIG REQUIRED)

add_executable(BoidsCppSDL Sources/Main.cpp)
target_compile_features(BoidsCppSDL PRIVATE cxx_std_23)
target_link_libraries(BoidsCppSDL PRIVATE SDL3::SDL3)
