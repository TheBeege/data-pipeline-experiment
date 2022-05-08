import pathlib

import pkg_resources
from setuptools import setup

with pathlib.Path('requirements.txt').open() as requirements_txt:
    install_requires = [
        str(requirement)
        for requirement
        in pkg_resources.parse_requirements(requirements_txt)
        if 'prefect' not in str(requirement)
    ]

setup(
    name='flow_twitter_data',
    version='0.0.0',
    description='Collects data from Twitter, surprise!',
    author='Beege',
    # author_email='foomail@foo.com',
    packages=['flow_twitter_data'],  # would be the same as name
    # external packages acting as dependencies
    install_requires=install_requires,
)
