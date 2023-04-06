import ..app
echo 'Library at: ' + app.build_lib('example', {
  root: './tests/bindings',
  files: [
    'tests/sample.c'
  ],
  link_dirs: [
    'C:\\Users\\kite\\Test'
  ],
  output_dir: './.blade/bin/'
})


echo 'Output: ' + app.build('/Users/mcfriendsy/CLionProjects/bpdf')