from setuptools import setup, find_packages

setup(
    name='aiy-projects-python',
    version='2.0.0',
    description='AIY Python API (Voice Kit v1 port for Raspberry Pi OS Trixie)',
    long_description='A set of Python APIs designed for the AIY Voice Kit and AIY Vision Kit, which help you build intelligent systems that can understand what they hear and see.',
    author='AIY Team',
    author_email='support-aiyprojects@google.com',
    url="https://aiyprojects.withgoogle.com/",
    project_urls={
        'GitHub: issues': 'https://github.com/google/aiyprojects-raspbian/issues',
        'GitHub: repo': 'https://github.com/google/aiyprojects-raspbian',
    },
    license='Apache 2',
    packages=find_packages('src'),
    package_dir={'': 'src'},
    # These come from apt (python3-*) and are seen through a venv created with
    # --system-site-packages; RPi.GPIO is provided by python3-rpi-lgpio. Audio and
    # TTS run alsa-utils and pico2wave (libttspico-utils) as subprocesses.
    install_requires=[
        'gpiozero',
    ],
    extras_require={
        # aiy.cloudspeech; not yet ported to google-cloud-speech 2.x.
        'cloudspeech': [
            'google-cloud-speech',
        ],
    },
    python_requires='>=3.9',
)
