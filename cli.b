import os
import io
import .app

var config_file = os.join_paths(os.dir_name(os.current_file()), 'config.json')
var setup_file = os.join_paths(os.dir_name(os.current_file()), 'setup.b')

try {
  if !file(config_file).exists() {
    echo '*kite: Setting up build dependencies...'
    if !os.exec('${os.args[0]} ${setup_file}') {
      die Exception('failed to setup build dependencies.')
    }
  }

  var output = app.build(os.cwd())
  echo '*kite: Successfully build project to ${output}'
} catch Exception e {
  io.stderr.write('Error: ' + e.message + '\n')
  os.exit(11)
}
