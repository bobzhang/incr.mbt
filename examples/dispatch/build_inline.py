#!/usr/bin/env python3
"""Embed the compiled engine directly in a conversation visualization fragment."""
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
subprocess.run(['python3', str(HERE / 'build.py')], check=True)
engine = (ROOT / '_build/js/release/build/examples/dispatch/bridge/bridge.js').read_text()
exports = re.search(r'export \{ (\w+) as reset, (\w+) as update \}\s*$', engine)
if not exports:
    raise RuntimeError('Unexpected MoonBit export shape; inspect the generated bridge')
# Ordinary script closure: no module loads, network, eval, or simulated engine.
engine = engine[:exports.start()] + f'const reset = {exports[1]};\nconst update = {exports[2]};\n'
fragment = (HERE / 'web/inline.html').read_text().replace('/* COMPILED_ENGINE */', engine.replace('</script', '<\\/script'))
destination = ROOT / '_build/dispatch/inline.html'
destination.write_text(fragment)
print(destination)
