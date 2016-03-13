import os
import os.path

cwd = os.path.dirname(os.path.abspath(__file__))

flags = [
    '-g',
    '-fPIC',
    '-Wall',
    '-Wextra',
    '-Werror',
    '-Wextra',
    '-Wconversion',
    '-Wstrict-prototypes',
    '-pedantic',
    '-isystem',
    os.path.join(cwd, '.deps', 'usr', 'include')
]

def FlagsForFile(filename, **kwargs):
  return {
    'flags': flags,
    'do_cache': True
  }
