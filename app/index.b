import json
import os
import iters

var EXE = 'exe'
var SHARED = 'shared'
var STATIC = 'static'

var _INSTALL_ERROR = 'kite installation failed. reinstall.'
var _is_windows = os.platform == 'windows'
var _is_linux = os.platform == 'linux'
var _is_osx = os.platform == 'osx'

# init root directory
var root_dir = os.join_paths(os.dir_name(os.current_file()), '..')

# init build directory
var build_dir = os.join_paths(root_dir, '.build')
if !os.dir_exists(build_dir) os.create_dir(build_dir)

# init config file path
var config_file_path = os.join_paths(root_dir, 'config.json')

def _get_config() {
  var config_file = file(config_file_path)
  if !config_file.exists() die Exception(_INSTALL_ERROR)

  var config = json.decode(config_file.read())
  config.blade_dir = os.dir_name(os.exe_path)
  config.build_dir = build_dir

  return config
}

def _copy_dir(from, to) {
  if !os.dir_exists(to) os.create_dir(to)

  if from {
    if os.dir_exists(from) {
      for f in os.read_dir(from) {
        if f != '.' and f != '..' {
          var from_name = os.join_paths(from, f)
          var to_name = os.join_paths(to, f)

          if os.is_dir(from_name) {
            _copy_dir(from_name, to_name)
          } else {
            file(from_name).copy(to_name)
          }
        }
      }
    }
  }
}

def _get_files(root) {
  var result = []
  if root {
    for f in os.read_dir(root) {
      if f != '.' and f != '..' {
        var path = os.join_paths(root, f)
        if os.dir_exists(path) {
          result.extend(_get_files(path))
        } else {
          if _is_windows
            result.append(os.real_path(path).replace('\\', '\\\\', false))
          else result.append(os.real_path(path))
        }
      }
    }
  }
  return result
}

def _init_build_dir(dir, name, type) {
  var build_dir = os.join_paths(dir, name)
  if os.dir_exists(build_dir) 
    os.remove_dir(build_dir, true)
  if file(build_dir).exists()
    file(build_dir).delete()

  if type == EXE {
    build_dir += '_exe'
    if os.dir_exists(build_dir) 
      os.remove_dir(build_dir, true)
    if file(build_dir).exists()
      file(build_dir).delete()
  }

  return build_dir
}

def _enforce_list(items) {
  if !is_list(items) 
    die Exception('invalid include directories')
  for item in items {
    if !is_string(item)
      die Exception('invalid include directory ${item}')
  }

  return items
}

def _enforce_string(item) {
  if !is_string(item)
    die Exception('invalid include directory ${item}')
  return item
}

def _transform_path(item) {
  if _is_windows return '"${os.real_path(item)}"'
  return '"${os.real_path(item).replace("\\", "\\\\", false)}"'
}

def _do_build(type, name, options) {
  if !options options = {}

  # allow overriding name from the options.
  name = options.get('name', name)

  var standard = options.get('standard', 11)
  var include_dirs = iters.map(_enforce_list(options.get('include_dirs', [])), _transform_path)
  var link_dirs = iters.map(_enforce_list(options.get('link_dirs', [])), _transform_path)
  var language = _enforce_string(options.get('language', 'c')).upper()
  var root = options.get('root', nil)

  var config = _get_config()
  var files = ''

  if root {
    files += '"' + '"\n  "'.join(
      iters.filter(_get_files(root), | f | {
        if language == 'C'
          return f.ends_with('.c') or f.ends_with('.h') 
        else return f.ends_with('.cpp') or f.ends_with('.cc') or f.ends_with('.cxx') or f.ends_with('.h') or f.ends_with('.hpp') 
      })
    ) + '"'
  }

  # add sources passed through options.
  var source_files = options.get('files', [])
  var win_source_files = options.get('windows_files', [])
  var osx_source_files = options.get('osx_files', [])
  var linux_source_files = options.get('linux_files', [])
  var unix_source_files = options.get('unix_files', [])
  
  if source_files {
    files += '\n  ' + '\n  '.join(iters.map(source_files, _transform_path))
  }
  if win_source_files and _is_windows {
    files += '\n  ' + '\n  '.join(iters.map(win_source_files, _transform_path))
  }
  if linux_source_files and _is_linux {
    files += '\n  ' + '\n  '.join(iters.map(linux_source_files, _transform_path))
  }
  if osx_source_files and _is_osx {
    files += '\n  ' + '\n  '.join(iters.map(osx_source_files, _transform_path))
  }
  if unix_source_files and _is_osx {
    files += '\n  ' + '\n  '.join(iters.map(unix_source_files, _transform_path))
  }

  if language == 'CXX' {
    config.gcc = config.gcc.replace('/gcc$/', 'g++').replace('/cc$/', 'clang++')
  }

  var output_dir = os.real_path(options.get('output_dir', config.build_dir))

  # create output directory if it does not exists.
  if !os.dir_exists(output_dir) 
    os.create_dir(output_dir)

  var cmake_lists = 'cmake_minimum_required(VERSION 3.18)\n' +
    'project(${name} ${language})\n\n' +
    'set(CMAKE_${language}_STANDARD ${standard})\n' +
    'set(CMAKE_${language}_STANDARD_REQUIRED True)\n' +
    'set(CMAKE_MAKE_PROGRAM "${config.make}")\n' +
    'set(CMAKE_${language}_COMPILER "${config.gcc}")\n'
  
  if type != EXE {
    cmake_lists += 'set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${output_dir}")\n' +
      'set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${output_dir}")\n' +
      (type == SHARED ? 'set(CMAKE_SHARED_LIBRARY_PREFIX "")\n' : '')
  } else {
    cmake_lists += 'set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${output_dir}")\n'
  }

  cmake_lists += 'file(MAKE_DIRECTORY "${output_dir}")'
  
  if root {
    cmake_lists += '\ninclude_directories("${config.blade_dir}/includes" "${root}" ${" ".join(include_dirs)})\n' +
      'link_directories("${config.blade_dir}" ${" ".join(link_dirs)})\n' +
      '\n'
  } else {
    cmake_lists += '\ninclude_directories("${config.blade_dir}/includes" ${" ".join(include_dirs)})\n' +
      'link_directories("${config.blade_dir}" ${" ".join(link_dirs)})\n' +
      '\n'
  }
    
  if type == EXE {
    cmake_lists += 'add_executable(${name}\n  ${files.trim()})\n'
  } else if type == STATIC {
    cmake_lists += 'add_library(${name}\n  ${files.trim()})\n'
  } else {
    cmake_lists += 'add_library(${name} SHARED\n  ${files.trim()})\n'
  }

  var flags = ' '.join(options.get('flags', [])).trim()
  var linux_flags = ' '.join(options.get('linux_flags', [])).trim()
  var windows_flags = ' '.join(options.get('windows_flags', [])).trim()
  var osx_flags = ' '.join(options.get('osx_flags', [])).trim()
  var unix_flags = ' '.join(options.get('unix_flags', [])).trim()

  cmake_lists +=  'target_link_libraries(${name} blade)\n' +
    '\n' +
    'set(CMAKE_${language}_FLAGS "\${CMAKE_${language}_FLAGS} ${flags}") # all\n' +
    'if(\${CMAKE_SYSTEM_NAME} STREQUAL "Linux")\n' +
    '  set(CMAKE_${language}_FLAGS "\${CMAKE_${language}_FLAGS} -fPIC ${linux_flags}") # linux\n' + # user flags passed after -fPIC to allow override.
    'endif()\n' +
    'if(WIN32 OR MINGW)\n' +
    '    set(CMAKE_${language}_FLAGS "\${CMAKE_${language}_FLAGS} -Wno-pointer-to-int-cast ${windows_flags}") # windows\n' + # same here...
    'endif()\n' +
    'if(APPLE)\n' +
    '    set(CMAKE_${language}_FLAGS "\${CMAKE_${language}_FLAGS} ${osx_flags}") # apple\n' + # same here...
    'endif()\n' +
    'if(UNIX)\n' +
    '    set(CMAKE_${language}_FLAGS "\${CMAKE_${language}_FLAGS} ${unix_flags}") # unix\n' + # same here...
    'endif()\n'

  cmake_lists += options.get('extra_script', '')

  # init build dorectory
  var build_dir = _init_build_dir(config.build_dir, name, type)

  # copy source to build directory
  _copy_dir(root, build_dir)

  # write out the cmake lists
  file(os.join_paths(build_dir, 'CMakeLists.txt'), 'w').write(cmake_lists.trim())

  os.change_dir(build_dir)

  var cmake_compile_cmd = '"${config.cmake}" -G "Unix Makefiles" .'

  var res
  if res = os.exec(cmake_compile_cmd) {
    if res = os.exec('"${config.cmake}" --build .') {
      # cleanup build directory
      os.remove_dir(build_dir, true)
      
      var regex = '/Linking C (shared|static) library([^\\n]+)/'
      if type == EXE regex = '/Linking C executable([^\\n]+)/'
      var lib_matches = res.match(regex)
      if lib_matches and lib_matches.length() > 2 {
        var lib_path = lib_matches[2].replace('/(\.\.\/)+/', '').trim()
        if file(lib_path).exists() {
          return os.real_path(lib_path)
        }

        return lib_path
      }

      return os.join_paths(output_dir, name)
    } else {
      # cleanup build directory
      os.remove_dir(build_dir, true)
      die Exception(res or 'CMake failure!')
    }
  } else {
    # cleanup build directory
    os.remove_dir(build_dir, true)
    die Exception(res or 'CMake failure!')
  }
}

/**
 * build_lib(name [, configuration])
 * 
 * Builds a shared library with the given name and kite configuration and 
 * returns the path to the generated artefact.
 * 
 * @param string name   The name of the library
 * @param dict configuration  A dictionary passing build configuration to the compiler (Optional)
 * @returns string   Path to the shared library
 */
def build_lib(name, configuration) {
  return _do_build(SHARED, name, configuration)
}

/**
 * build_static_lib(name [, configuration])
 * 
 * Same as build_lib(), but builds a static library instead.
 * 
 * @param string name   The name of the library
 * @param dict configuration  A dictionary passing build configuration to the compiler (Optional)
 * @returns string   Path to the static library
 */
def build_static_lib(name, configuration) {
  return _do_build(STATIC, name, configuration)
}

/**
 * build_exe(name [, configuration])
 * 
 * Same as build_lib(), but builds an executable instead.
 * 
 * @param string name   The name of the executable
 * @param dict configuration  A dictionary passing build configuration to the compiler (Optional)
 * @returns string   Path to the executable file
 */
def build_exe(name, configuration) {
  return _do_build(EXE, name, configuration)
}

/**
 * build(path)
 * 
 * Automatically build a kite project based on the given configuration file in the path.
 * 
 * The `kite.json` file can contain the following configurations:
 * 
 * - `type`:            The type of artefact the project will generate (one of `exe`, `shared` and `static`).
 * - `name`:            The name of the project
 * - `language`:        The language of the project (`C` or `CXX`) - Default: `C`.
 * - `standard`:        The standard of the project language - Default: 11 (i.e. C11).
 * - `include_dirs`:    List of directory to find header files in.
 * - `link_dirs`:       List of directories to find linkable libraries in.
 * - `root`:            The root of the library C source files (best used when all files are required on all platforms).
 * - `files`:           List of source files (`.c`, `.cpp`, `.h`, `.hpp` etc.) to compile.
 * - `unix_files`:      List of source files to compile on Unix/Unix-like only.
 * - `linux_files`:     List of source files to compile on Linux OSes only.
 * - `osx_files`:       List of source files to compile on MacOS only.
 * - `windows_files`:   List of source files to compile on Windows OSes only.
 * - `flags`:           Extra compile flags to be passed to compiler on all OS.
 * - `linux_flags`:     Extra compile flags to be passed to compiler on Linux OSes.
 * - `windows_flags`:   Extra compile flags to be passed to compiler on Windows OSes.
 * - `osx_flags`:       Extra compile flags to be passed to compiler on MacOS.
 * - `unix_flags`:      Extra compile flags to be passed to compiler on all Unix/Unix-like OS.
 * - `output_dir`:      The directory in which the build output will be placed in.
 * - `extra_script`:    Custom CMakeLists script to add to the autogenerated one.
 * 
 * @param string path   The path to the kite project directory
 * @returns string   Path to the output file
 */
def build(path, output_dir) {
  if !os.is_dir(path) or !os.dir_exists(path)
    die Exception('path must point to a directory.')
  path = os.real_path(path)

  var build_config_file = file(os.join_paths(path, 'kite.json'))
  if !build_config_file.exists()
    die Exception('the directory does not contain a kite configuration file.')

  var config = json.decode(build_config_file.read())
  if !is_dict(config) or !config.contains('name') or !config.name
    die Exception('invalid kite configuration encountered.')

  var type = config.get('type', SHARED)
  if ![EXE, SHARED, STATIC].contains(type)
    die Exception('unknown build type specified')

  # save the current directory
  var current_dir = os.cwd()
  # run the build as at the path.
  if current_dir != path os.change_dir(path)

  if !output_dir and config.contains('output_dir') {
    output_dir = config.get('output_dir')
  } else if !output_dir {
    output_dir = os.join_paths(os.cwd(), '.blade/bin')
  }

  if output_dir {
    output_dir = output_dir.replace('/\\\\|\\//', os.path_separator)
    if !os.is_dir(output_dir) and !os.dir_exists(output_dir)
      os.create_dir(output_dir)
    
    config.output_dir = os.real_path(output_dir)
  }

  if type == EXE return build_exe(config.name, config)
  else if type == SHARED return build_lib(config.name, config)
  else return build_static_lib(config.name, config)

  return nil
}

/**
 * tools()
 * 
 * Returns a dictionary that contains information about the build tools used by `kite`.
 * 
 * @returns dictionary
 */
def tools() {
  return _get_config()
}
