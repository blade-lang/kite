import json
import os
import iters

var _INSTALL_ERROR = 'kite installation failed. reinstall.'

# init root directory
var root_dir = os.join_paths(os.dir_name(os.current_file()), '..')

# init build directory
var build_dir = os.join_paths(root_dir, '.build')
if !os.dir_exists(build_dir) os.create_dir(build_dir)

# init config file path
var config_file_path = os.join_paths(root_dir, 'config.json')

def _get_config() {
  var config_file = file(config_file_path)
  if !config_file.exists() die Excpetion(_INSTALL_ERROR)

  var config = json.decode(config_file.read())
  config.blade_dir = os.dir_name(os.exe_path)
  config.build_dir = build_dir

  return config
}

def _copy_dir(from, to) {
  if os.dir_exists(from) {
    if !os.dir_exists(to) os.create_dir(to)

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

def _get_files(root) {
  var result = []
  for f in os.read_dir(root) {
    if f != '.' and f != '..' {
      var path = os.join_paths(root, f)
      if os.dir_exists(path) {
        result.extend(_get_files(path))
      } else {
        result.append(os.real_path(path))
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

  if type == 'executable' {
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
    die Excpetion('invalid include directory ${item}')
  return item
}

def cmake(root) {
  var config = _get_config()
  echo config
}

def _auto_build(type, name, root, options) {
  if !options options = {}

  var standard = options.get('standard', 11)
  var include_dirs = iters.map(_enforce_list(options.get('include_dirs', [])), | item | {
    return '"${item}"'
  })
  var link_dirs = iters.map(_enforce_list(options.get('link_dirs', [])), | item | {
    return '"${item}"'
  })
  var language = _enforce_string(options.get('language', 'c')).upper()

  var config = _get_config()
  var files = '\n  '.join(
    iters.filter(_get_files(root), | f | { 
      return f.ends_with('.c') or f.ends_with('.h') 
    })
  )

  if language == 'CXX' {
    config.gcc = config.gcc.replace('/gcc$/', 'g++').replace('/cc$/', 'clang++')
  }

  var cmake_lists = 'cmake_minimum_required(VERSION 3.18)\n' +
    'project(${name} ${language})\n' +
    'set(CMAKE_${language}_STANDARD ${standard})\n' +
    'set(CMAKE_${language}_STANDARD_REQUIRED True)\n'
  
  if type == 'library' {
    cmake_lists += 'set(CMAKE_SHARED_LIBRARY_PREFIX "")\n'
  }
    
  cmake_lists += 'set(BLADE_ROOT "${config.blade_dir}")\n' +
    'set(SRC_ROOT "${root}")\n' +
    'include_directories("\${BLADE_ROOT}/includes" \${SRC_ROOT} ${" ".join(include_dirs)})\n' +
    'link_directories(\${BLADE_ROOT} ${" ".join(link_dirs)})\n' +
    '\n'
    
  if type == 'executable' {
    cmake_lists += 'add_executable(${name} ${files})\n'
  } else if type == 'static' {
    cmake_lists += 'add_library(${name} ${files})\n'
  } else {
    cmake_lists += 'add_library(${name} SHARED ${files})\n'
  }

  cmake_lists +=  'target_link_libraries(${name} blade)\n' +
    '\n' +
    'if(\${CMAKE_SYSTEM_NAME} STREQUAL "Linux")\n' +
    '  set(CMAKE_${language}_FLAGS "\${CMAKE_${language}_FLAGS} -fPIC")\n' +
    'endif()\n' +
    'if(WIN32 OR MINGW)\n' +
    '    set(CMAKE_${language}_FLAGS "\${CMAKE_${language}_FLAGS} -Wno-pointer-to-int-cast")\n' +
    'endif()\n' +
    '\n' +
    'add_custom_command(TARGET ${name} POST_BUILD\n' +
    '        COMMAND \${CMAKE_COMMAND} -E copy $<TARGET_FILE:${name}> "${config.build_dir}")'

  # init build dorectory
  var build_dir = _init_build_dir(config.build_dir, name, type)

  # copy source to build directory
  _copy_dir(root, build_dir)

  # write out the cmake lists
  file(os.join_paths(build_dir, 'CMakeLists.txt'), 'w').write(cmake_lists.trim())

  os.change_dir(build_dir)

  var cmake_compile_cmd = '"${config.cmake}" -G "Unix Makefiles" . -DCMAKE_${language}_COMPILER="${config.gcc}" -DCMAKE_MAKE_PROGRAM="${config.make}"'

  var res
  if res = os.exec(cmake_compile_cmd) {
    if res = os.exec('"${config.cmake}" --build .') {
      
      var regex = '/Linking C (shared|static) library([^\\n]+)/'
      if type == 'executable' regex = '/Linking C executable([^\\n]+)/'
      var lib_matches = res.match(regex)
      if lib_matches and lib_matches.length() > 2 {
        var lib_path = os.join_paths(config.build_dir, lib_matches[2].replace('/(\.\.\/)+/', '').trim())
        if file(lib_path).exists() {
          return os.real_path(lib_path)
        }

        return lib_path
      }

      return os.join_paths(config.build_dir, name)
    } else {
      die Exception(res or 'CMake failure!')
    }
  } else {
    die Exception(res or 'CMake failure!')
  }
}

/**
 * auto_lib(name, root)
 * 
 * Recursively reads a directory to get a list of source files to 
 * create a library, and creates a CMakeLists.txt file that 
 * can be used to build a shared library. It also adds a custom target to 
 * copy the source files to the libs folder and a custom command to copy 
 * the library to the dist folder. The auto_lib() function takes 
 * two parameters, a name and a root directory.
 * 
 * @param string name   The name of the library
 * @param string root   The root of the library C source files
 * @param options dict  A dictionary passing build options to the compiler (Optional)
 * @return string path to the shared library
 */
def auto_lib(name, root, options) {
  return _auto_build('library', name, root, options)
}

/**
 * auto_static_lib(name, root)
 * 
 * Same as auto_lib(), but builds a static library instead.
 * 
 * @param string name   The name of the library
 * @param string root   The root of the library C source files
 * @param options dict  A dictionary passing build options to the compiler (Optional)
 * @return string path to the static library
 */
def auto_static_lib(name, root, options) {
  return _auto_build('static', name, root, options)
}

/**
 * auto_exe(name: string, root: string)
 * 
 * Same as auto_lib(), but builds an executable instead.
 * 
 * @param string name   The name of the executable
 * @param string root   The root of the executable C source files
 * @param options dict  A dictionary passing build options to the compiler (Optional)
 * @return string path to the executable file
 */
def auto_exe(name, root, options) {
  return _auto_build('executable', name, root, options)
}
