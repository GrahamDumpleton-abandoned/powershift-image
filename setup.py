import sys
import os

from setuptools import setup

long_description = open('README.rst').read()

classifiers = [
    'Development Status :: 4 - Beta',
    'License :: OSI Approved :: BSD License',
    'Programming Language :: Python :: 2',
    'Programming Language :: Python :: 2.7',
    'Programming Language :: Python :: 3',
    'Programming Language :: Python :: 3.3',
    'Programming Language :: Python :: 3.4',
    'Programming Language :: Python :: 3.5',
    'Programming Language :: Python :: 3.6',
]

setup_kwargs = dict(
    name='powershift-image',
    version='1.4.2',
    description='PowerShift command plugin for working in S2I images.',
    long_description=long_description,
    url='https://github.com/getwarped/powershift-image',
    author='Graham Dumpleton',
    author_email='Graham.Dumpleton@gmail.com',
    license='BSD',
    classifiers=classifiers,
    keywords='openshift kubernetes',
    packages=['powershift', 'powershift.image', 'powershift.image.scripts'],
    package_dir={'powershift': 'src/powershift'},
    extras_require={'cli': ['powershift-cli>=1.2.0']},
    entry_points = {'powershift_cli_plugins': ['image = powershift.image']},
    package_data = {'powershift.image.scripts': ['alive.sh', 'assemble.sh',
        'exec.sh', 'jobs.sh', 'migrate.sh', 'ready.sh', 'run.sh', 'setup.sh',
        'shell.sh', 'verify.sh']},
)

setup(**setup_kwargs)
