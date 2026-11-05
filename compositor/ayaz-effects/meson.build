project('ayaz-effects', 'cpp', version: '0.1.0', default_options: ['cpp_std=c++17', 'buildtype=release'])
wayfire = dependency('wayfire')
add_project_arguments(['-DWLR_USE_UNSTABLE', '-DWAYFIRE_PLUGIN'], language: 'cpp')
shared_module('ayaz-effects', 'ayaz-effects.cpp',
    dependencies: [wayfire],
    install: true, install_dir: wayfire.get_variable(pkgconfig: 'plugindir'))
install_data('ayaz-effects.xml', install_dir: wayfire.get_variable(pkgconfig: 'metadatadir'))
