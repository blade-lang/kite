# kite

A package that helps to build C extensions for Blade as well as other C/C++ applications from a Blade script/project. Kite does not replace a build system, but rather sets up a build system for you and leverage them accordingly.


## Package Information
---

- **Name:** git
- **Version:** 1.0.0
- **Homepage:** [https://github.com/blade-lang/kite](https://github.com/blade-lang/kite)
- **Tags:** `build`, `gcc`, `compiler`, `build-system`, `extension`, `c`, `package`, `library`.
- **Author:** Richard Ore <eqliqandfriends@gmail.com>
- **License:** ISC


## Installation
---

Kite can be installed via Nyssa using the following command:

```
nyssa install -g kite
```

**It is recommended to install `kite` globally! This way you get the `kite` CLI too that allows you to easily develop C extensions/applications**

During `kite` installation, it will attempt to locate build tools installed on the current machine and attempt to download/install any missing required build tool. If a package does exists, `kite` will continue to use the existing tool.

Kite requires the following build tools (it will download/install any missing):

- Make
- C/C++ Compiler toolchain


## Usage
---

The simplest way to use `kite` is to use it as an auto builder. To do this you must first, 

1. Create a `kite.json` file at the root of the project you want to build 
2. Add your [kite configuration](#kite-configuration) to the file.

After the above steps, you have two ways of building the project. Firstly, via the CLI if you've installed Kite globally as recommended.

Simply run the command `kite` from the root of the application.

If you have installed `kite` locally, you can build your project by running the following from a script of the Blade REPL.


```
import kite

var artefact = kite.build('/path/to/my/project/')
echo 'Artefact: ${artefact}'
```


## Kite Configuration
---

The `kite.json` file can contain the following configuration:

| Configuration | Description |
|---------------|-------------|
| `type`           | The type of artefact the project will generate (one of `exe`, `shared` and `static`). |
| `name`           | The name of the project. |
| `language`       | The language of the project (`c`, `cxx`, or `c++`) - Default: `c`. |
| `standard`       | The standard of the project language - Default: 11 (i.e. C11). |
| `include_dirs`   | List of directory to find header files in. |
| `link_dirs`      | List of directories to find linkable libraries in. |
| `root`           | The root of the library C source files (best used when all files are required on all platforms). |
| `files`          | List of source files (`.c`, `.cpp`, `.h`, `.hpp` etc.) to compile. |
| `unix_files`     | List of source files to compile on Unix/Unix-like only. |
| `linux_files`    | List of source files to compile on Linux OSes only. |
| `osx_files`      | List of source files to compile on MacOS only. |
| `windows_files`  | List of source files to compile on Windows OSes only. |
| `flags`          | List of extra compile flags to be passed to compiler on all OS. |
| `linux_flags`    | List of extra compile flags to be passed to compiler on Linux OSes. |
| `windows_flags`  | List of extra compile flags to be passed to compiler on Windows OSes. |
| `osx_flags`      | List of extra compile flags to be passed to compiler on MacOS. |
| `unix_flags`     | List of extra compile flags to be passed to compiler on all Unix/Unix-like OS. |
| `output_dir`     | The directory in which the build output will be placed in. |


Only the `name` of a project is required configuration. All others are optional. Here is an example of a valid `kite.json` file.


```
{
  "name": "bpdf",
  "root": "./c-sources",
  "standard": 99,
  "files": [
    "some/random/file.c"
  ],
  "flags": [
    "-Wno-error"
  ],
  "include_dirs": [
    "./my_subdirectory"
  ]
}
```


## API Documentation
---

Kite can be used as a CLI as well as a library from other applications. Kite exports the following functions for use from other modules that imports it.


- `build(path)`:
  
  Automatically build a kite project based on the given configuration file in the path.
  
  - **@params** *string* `path`: The path to the kite project directory
  - **@returns** *string*:  Path to the output file.


- `build_lib(name [, configuration])`:
  
  Builds a shared library with the given name and kite configuration and returns the path to the generated artefact.
  
  - **@params** *string* `name`:   The name of the executable
  - **@params** *dictionary* `configuration`: A dictionary passing build configuration to the compiler (Optional)
  - **@returns** *string*:   Path to the executable file.


- `build_static_lib(name, configuration)`:
  
  Same as `build_lib()`, but builds a static library instead.
  
  - **@params** *string* `name`:   The name of the executable.
  - **@params** *dictionary* `configuration`: A dictionary passing build configuration to the compiler (Optional)
  - **@returns** *string*:   Path to the executable file.


- `build_exe(name [, configuration])`:
  
  Same as `build_lib()`, but builds an executable instead.
  
  - **@params** *string* `name`:   The name of the executable.
  - **@params** *dictionary* `configuration`: A dictionary passing build configuration to the compiler (Optional)
  - **@returns** *string*:   Path to the executable file.


- `tools()`:
  
  Returns a dictionary that contains information about the build tools used by `kite`.
  
  - **@returns** *dictionary*


## Limitations
---

Because `kite` leverages `make` as its build tool, Kite is currently limited to only what can be acheived through make on any platform and is subject to any bugs that may exist or not in make on said platform.

