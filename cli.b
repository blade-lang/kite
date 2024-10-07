import os
import io
import .app

var config_file = os.join_paths(os.dir_name(__file__), 'config.json')
var setup_file = os.join_paths(os.dir_name(__file__), 'setup.b')

catch {
  if !file(config_file).exists() {
    echo '*kite: Setting up build dependencies...'
    if !os.exec('${os.args[0]} ${setup_file}') {
      raise Exception('failed to setup build dependencies.')
    }
  }

  var output = app.build(os.cwd())
  echo '*kite: Successfully build project to ${output}'
} as e 

if e {
  io.stderr.write('Error: ' + e.message + '\n')
  os.exit(1)
}
