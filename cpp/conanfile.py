from conan import ConanFile
from conan.tools.cmake import CMakeDeps, CMakeToolchain, cmake_layout


class HmNvbenchProfileConan(ConanFile):
    name = "hmdemo-nvbench-profile"
    version = "0.1.0"
    package_type = "application"
    settings = "os", "compiler", "build_type", "arch"

    def requirements(self):
        self.requires("cli11/2.5.0")
        self.requires("fmt/11.2.0")
        self.requires("nlohmann_json/3.12.0")
        self.requires("tomlplusplus/3.4.0")

    def layout(self):
        cmake_layout(self)

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()
        tc = CMakeToolchain(self)
        tc.generate()
