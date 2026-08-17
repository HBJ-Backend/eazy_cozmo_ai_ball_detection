from setuptools import setup, find_packages

setup(
    name='easy_cozmo',
    version='1.0',
    description='K-12 robotics wrapper library over the Anki/DDL Cozmo SDK',
    packages=find_packages(include=['easy_cozmo', 'easy_cozmo.*']),
    package_data={'easy_cozmo.themes.soccer': ['*.pt']},
    include_package_data=True,
)
