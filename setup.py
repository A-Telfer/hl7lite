from setuptools import setup, Extension  # type: ignore
from Cython.Build import cythonize  # type: ignore
from Cython.Compiler.Options import get_directive_defaults
import lxml  # type: ignore
import os

# Set this by saying `PROFILE=1 pip install .``
profile = os.environ.get("PROFILE", "") == '1'

compiler_directives = get_directive_defaults()
compiler_directives["language_level"] = 3

annotate = False

macros = []
if profile:
    compiler_directives["profile"] = profile
    compiler_directives['linetrace'] = profile
    compiler_directives['binding'] = profile
    
    macros = [
        ("CYTHON_TRACE", "1"),
        ("CYTHON_TRACE_NOGIL", "1"),
    ]

    annotate = True

setup(
    ext_modules=cythonize(
        module_list=[
            Extension(
                name="hl7lite.cython.parse",
                sources=["src/hl7lite/cython/parse.pyx"],
                include_dirs=[os.path.join(lxml.__path__[0], "includes")],
                define_macros=macros,
                profile=profile,
            )
        ],
        compiler_directives=compiler_directives,
        aliases={"LXML_PACKAGE_DIR": lxml.__path__},
        annotate=annotate,
    ),
)
