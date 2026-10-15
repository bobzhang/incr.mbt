#!/usr/bin/env python3
"""Build a portable, self-contained dispatch demo with the real MoonBit engine."""
import base64
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
subprocess.run(['moon', 'build', '--release', '--target', 'js', 'examples/dispatch/bridge'], cwd=ROOT, check=True)
engine = ROOT / '_build/js/release/build/examples/dispatch/bridge/bridge.js'
module_url = 'data:text/javascript;base64,' + base64.b64encode(engine.read_bytes()).decode('ascii')
app = (HERE / 'web/app.js').read_text().replace("'./engine.js'", repr(module_url))
html = (HERE / 'web/index.html').read_text()
html = html.replace('<link rel="stylesheet" href="style.css">', '<style>\n' + (HERE / 'web/style.css').read_text() + '\n</style>')
html = html.replace('<script type="module" src="app.js"></script>', '<script type="module">\n' + app.replace('</script', '<\\/script') + '\n</script>')
destination = ROOT / '_build/dispatch'
destination.mkdir(parents=True, exist_ok=True)
(destination / 'index.html').write_text(html)
print(destination / 'index.html')
