import json
import os

var EXE = 'exe'
var SHARED = 'shared'
var STATIC = 'static'

var _INSTALL_ERROR = 'Kite installation failed. Run "kite" command to fix.'
var _is_windows = os.platform == 'windows'
var _is_linux = os.platform == 'linux'
var _is_osx = os.platform == 'osx'

# init root directory
var root_dir = os.join_paths(os.dir_name(__file__), '..')

# init build directory
var build_dir = os.join_paths(root_dir, '.build')
if !os.dir_exists(build_dir) os.create_dir(build_dir)

# init config file path
var config_file_path = os.join_paths(root_dir, 'config.json')

def _get_config() {
  var config_file = file(config_file_path)
  if !config_file.exists() raise Exception(_INSTALL_ERROR)

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
    raise Exception('invalid include directories')
  for item in items {
    if !is_string(item)
      raise Exception('invalid include directory ${item}')
  }

  return items
}

def _enforce_string(item) {
  if !is_string(item)
    raise Exception('invalid include directory ${item}')
  return item
}

def _transform_path(item) {
  if !_is_windows return '"${os.real_path(item)}"'
  return '"${os.real_path(item).replace("\\", "\\\\", false)}"'
}

def _do_build(type, name, options) {
  if !options options = {}

  # allow overriding name from the options.
  name = options.get('name', name)

  var standard = options.get('standard', 11)
  var include_dirs = _enforce_list(options.get('include_dirs', [])).map(_transform_path)
  var link_dirs = _enforce_list(options.get('link_dirs', [])).map(_transform_path)
  var language = _enforce_string(options.get('language', 'c')).lower()
  var root = options.get('root', nil)

  var config = _get_config()
  var files = ''

  if root {
    files += ' ' + ' '.join(
      _get_files(root).filter(@(f) {
        if language == 'c'
          return f.ends_with('.c')
        else return f.ends_with('.cpp') or f.ends_with('.cc') or f.ends_with('.cxx') 
      })
    )

    # add root to include directories
    include_dirs.append(root)
  }

  # add sources passed through options.
  var source_files = options.get('files', [])
  var win_source_files = options.get('windows_files', [])
  var osx_source_files = options.get('osx_files', [])
  var linux_source_files = options.get('linux_files', [])
  var unix_source_files = options.get('unix_files', [])
  
  if source_files {
    files += ' ' + ' '.join(source_files.map(_transform_path))
  } else if win_source_files and _is_windows {
    files += ' ' + ' '.join(win_source_files.map(_transform_path))
  } else if linux_source_files and _is_linux {
    files += ' ' + ' '.join(linux_source_files.map(_transform_path))
  } else if osx_source_files and _is_osx {
    files += ' ' + ' '.join(osx_source_files.map(_transform_path))
  } else if unix_source_files and (_is_osx or _is_linux) {
    files += ' ' + ' '.join(unix_source_files.map(_transform_path))
  }

  if language == 'cxx' or language == 'c++' {
    config.gcc = config.gcc.replace('/gcc$/', 'g++').replace('/cc$/', 'clang++')
  }

  # add required include directories
  include_dirs.append('"${config.blade_dir}/includes"')
  link_dirs.append('"${config.blade_dir}"')

  var flags = ' '.join(options.get('flags', [])).trim()
  var linux_flags = ' '.join(options.get('linux_flags', [])).trim()
  var windows_flags = ' '.join(options.get('windows_flags', [])).trim()
  var osx_flags = ' '.join(options.get('osx_flags', [])).trim()
  var unix_flags = ' '.join(options.get('unix_flags', [])).trim()

  if windows_flags and _is_windows {
    flags.extend(windows_flags)
  } else if linux_flags and _is_linux {
    flags.extend(linux_flags)
  } else if osx_flags and _is_osx {
    flags.extend(osx_flags)
  } else if unix_flags and (_is_osx or _is_linux) {
    flags.extend(unix_flags)
  }

  var includes = ' '.join(include_dirs.map(@(i){ return '-I${i}' })).trim()
  var link_paths = (' '.join(link_dirs.map(@(i){ return '-L${i}' })) + ' -lblade').trim()
  var link_flags = ' '.join(flags).trim()

  if type != EXE {
    if type == STATIC {
      link_flags += ' -static'
    } else {
      link_flags += ' -shared'
    }
  }
  
  var output_dir = os.real_path(options.get('output_dir', config.build_dir))

  # create output directory if it does not exists.
  if !os.dir_exists(output_dir) 
    os.create_dir(output_dir)

  # init build dorectory
  var build_dir = _init_build_dir(config.build_dir, name, type)

  # copy source to build directory
  _copy_dir(root, build_dir)

  os.change_dir(build_dir)

  var ext = type == EXE ? (
    _is_windows ? '.exe' : ''
  ) : (
    _is_linux ? '.so' : (
      _is_windows ? '.dll' : '.dylib'
    )
  )
  var output_file = os.join_paths(output_dir, '${name}${ext}')

  var make_command = '${config.gcc} ${files} ${includes} ${link_paths} ${link_flags} -o "${output_file}"'

  var res
  if (res = os.exec(make_command)) == nil {
    # cleanup build directory
    os.remove_dir(build_dir, true)

    if file(output_file).exists() {
      return output_file
    } else {
      raise Exception(res or 'Build failed!')
    }
  } else {
    # cleanup build directory
    os.remove_dir(build_dir, true)
    raise Exception(res or 'Build failure!')
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
 * 
 * @param string path   The path to the kite project directory
 * @returns string   Path to the output file
 */
def build(path, output_dir) {
  if !os.is_dir(path) or !os.dir_exists(path)
    raise Exception('path must point to a directory.')
  path = os.real_path(path)

  var build_config_file = file(os.join_paths(path, 'kite.json'))
  if !build_config_file.exists()
    raise Exception('the directory does not contain a kite configuration file.')

  var config = json.decode(build_config_file.read())
  if !is_dict(config) or !config.contains('name') or !config.name
    raise Exception('invalid kite configuration encountered.')

  var type = config.get('type', SHARED)
  if ![EXE, SHARED, STATIC].contains(type)
    raise Exception('unknown build type specified')

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
