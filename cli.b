import os
import io
import .app

try {
  var output = app.build(os.cwd())
  echo '*kite: Successfully build project to ${output}'
} catch Exception e {
  io.stderr.write('Error: ' + e.message + '\n')
  os.exit(11)
}
