Pod::Spec.new do |spec|
  spec.name         = "ParkingLockiOS"
<<<<<<< HEAD
  spec.version      = "0.0.3"
=======
  spec.version      = "0.0.2"
>>>>>>> 52ebf37 (fix framework)
  spec.summary      = "A simple Parking Lock SDK"
  spec.description  = "Parking Lock SDK is a framework that will make it easy for you to implement your Parking Lock"

  spec.homepage     = "https://github.com/rilwanulhuda/parking-lock-ios"
  spec.license      = { :type => "MIT", :text => <<-LICENSE
                        MIT License

                        Copyright (c) 2023 rilwanulhuda

                        Permission is hereby granted, free of charge, to any person obtaining a copy
                        of this software and associated documentation files (the "Software"), to deal
                        in the Software without restriction, including without limitation the rights
                        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
                        copies of the Software, and to permit persons to whom the Software is
                        furnished to do so, subject to the following conditions:

                        The above copyright notice and this permission notice shall be included in all
                        copies or substantial portions of the Software.

                        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
                        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
                        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
                        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
                        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
                        SOFTWARE.
                        LICENSE
                    }
  spec.swift_versions = "5.0"
  spec.author             = { "rilwanulhuda" => "rilwanulhuda.dev@gmail.com" }
  spec.platform     = :ios, "10.0"
  spec.ios.deployment_target = "10.0"
<<<<<<< HEAD
  spec.ios.vendored_frameworks = "ParkingLockiOS.xcframework"
  spec.source       = { :http => "https://www.dropbox.com/s/fgt9gzt1hukyox2/ParkingLockiOS.xcframework.zip?dl=1" }
#  spec.source       = { :git => "https://github.com/rilwanulhuda/parking-lock-ios.git", :tag => spec.version.to_s }
#  spec.source_files  = "ParkingLockiOS/**/*.{swift}"
  spec.exclude_files = "Classes/Exclude"
=======
  #spec.ios.vendored_frameworks = "ParkingLockiOS.xcframework"
  #spec.source       = { :http => "https://www.dropbox.com/s/b07ych6gm4n5fi2/ParkingLockiOS.xcframework.zip?dl=1" }
  spec.source       = { :git => "https://github.com/rilwanulhuda/parking-lock-ios.git", :tag => spec.version.to_s }
  spec.source_files  = "ParkingLockiOS/**/*.{swift}"
  #spec.exclude_files = "Classes/Exclude"
>>>>>>> 52ebf37 (fix framework)

  # spec.public_header_files = "Classes/**/*.h"


  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  A list of resources included with the Pod. These are copied into the
  #  target bundle with a build phase script. Anything else will be cleaned.
  #  You can preserve files from being cleaned, please don't preserve
  #  non-essential files like tests, examples and documentation.
  #

  # spec.resource  = "icon.png"
  # spec.resources = "Resources/*.png"

  # spec.preserve_paths = "FilesToSave", "MoreFilesToSave"


  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  # spec.framework  = "SomeFramework"
  # spec.frameworks = "SomeFramework", "AnotherFramework"

  # spec.library   = "iconv"
  # spec.libraries = "iconv", "xml2"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If your library depends on compiler flags you can set them in the xcconfig hash
  #  where they will only apply to your library. If you depend on other Podspecs
  #  you can include multiple dependencies to ensure it works.

  # spec.requires_arc = true

  # spec.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
  # spec.dependency "JSONKit", "~> 1.4"

end
