
import http
import zip
import os
import json
import tar

var dev_tools_path = '/usr/bin/'

var linux_package_manager

if os.platform == 'linux' {
  for pm in ['apk', 'apt-get', 'yum', 'dnf', 'zypper', 'pacman'] {
    if os.exec('command -v ${pm}') {
      linux_package_manager = pm
      break
    }
  }

  if !linux_package_manager
    raise Exception('No supported package manager installed!')
}

def install_winlibs() {
  if !file('./winlibs.zip').exists() {
    echo 'Downloading WinLibs...'
    var winlibs_request = http.get('https://github.com/brechtsanders/winlibs_mingw/releases/download/12.1.0-14.0.6-10.0.0-msvcrt-r3/winlibs-x86_64-posix-seh-gcc-12.1.0-mingw-w64msvcrt-10.0.0-r3.zip')
    if winlibs_request.status != 200 
      raise Exception('Could not download WinLibs')
    file('./winlibs.zip', 'wb').write(winlibs_request.body)
  }
  
  if !os.dir_exists('./winlibs') {
    echo 'Installing WinLibs...'
    if !zip.extract('./winlibs.zip', './winlibs', false)
      raise Exception('Failed to extract winlibs')
  }

  echo 'WinLibs is installed.'
}

def install_build_essentials() {
  if ['linux', 'osx'].contains(os.platform) {
    if !os.exec('make --version') or !os.exec('gcc --version') {
      using os.platform {
        when 'linux' {
          echo 'Installing build essentials...'
          var installed
          using linux_package_manager {
            when 'apk' installed = os.exec('sudo apk add build-base -y')
            when 'pacman' installed = os.exec('sudo pacman -Sy base-devel -y')
            when 'dnf', 'yum' installed = os.exec('sudo ${linux_package_manager} groupinstall "Development Tools" -y')
            when 'zypper' installed = os.exec('sudo zypper install --type pattern devel_basis -y')
            default installed = os.exec('sudo apt-get install build-essential -y')
          }
  
          if !installed raise Exception('Failed to install OS build essentials')
          
          echo 'Build essentials is installed.'
        }
        when 'osx' {
          echo 'Installing Xcode command-line tools...'
          # install xcode command line tools
          if !os.exec('xcode-select --install')
            raise Exception('Failed to setup toolchain: could not install Xcode command-line tools')
          
            echo 'Xcode command-line is installed.'
        }
      }
    } else {
      echo 'Make is installed.'
      echo 'GCC or Clang is installed.'
    }
  } else {
    install_winlibs()
  }
}

var current_dir = os.dir_name(__file__)

# enter the .build directory
if !os.dir_exists('./.bin') os.create_dir('./.bin')
os.change_dir('./.bin')

# ensure toolchain is setup.
install_build_essentials()

var cc_name = os.platform == 'osx' ? 'cc' : 'gcc'
var make_name = os.platform == 'windows' ? 'mingw32-make' : 'make'

if os.platform == 'windows' {
  cc_name += '.exe'
  make_name += '.exe'
}

var toolchain = {
  gcc: os.join_paths(dev_tools_path, cc_name),
  make: os.join_paths(dev_tools_path, make_name),
  root_dir: current_dir,
}

os.change_dir('../')

file('config.json', 'w').write(json.encode(toolchain, false))
