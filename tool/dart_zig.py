#!/usr/bin/env python3
"""Local toolkit workflow; runtime consumers remain plain Dart packages."""
import argparse, json, os, pathlib, shutil, subprocess, sys, time
from schema_validation import validate
ROOT = pathlib.Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--config', type=pathlib.Path, default=ROOT/'dart_zig.json')
commands = parser.add_subparsers(dest='command', required=True)
for name in ['generate','watch','doctor']: commands.add_parser(name)
web = commands.add_parser('web'); web.add_argument('--run',action='store_true')
schema = commands.add_parser('schema'); schema.add_argument('--source',type=pathlib.Path,required=True); schema.add_argument('--output',type=pathlib.Path,required=True)
scaffold = commands.add_parser('scaffold'); scaffold.add_argument('destination',type=pathlib.Path); scaffold.add_argument('--name',default='zig_consumer')
args=parser.parse_args()
config=json.loads(args.config.read_text()); root=args.config.resolve().parent
zig=config.get('zig','zig'); dart=config.get('dart','dart')
env=os.environ.copy()
# Scripts invoke standard command names. Explicit paths select the configured toolchain.
for executable in [dart,zig]:
    if pathlib.Path(executable).is_absolute(): env['PATH']=str(pathlib.Path(executable).parent)+os.pathsep+env['PATH']
def run(command,**kwargs):
    try: return subprocess.run(command,cwd=root,env=env,check=True,**kwargs)
    except subprocess.CalledProcessError as error:
        if error.stderr: print(error.stderr,file=sys.stderr)
        raise
def generate():
    source=root/config.get('schema','schema.json')
    validate(json.loads(source.read_text()))
    # The bundled scripts expect the canonical intermediate filename.
    if source != root/'schema.json': shutil.copyfile(source,root/'schema.json')
    run(['sh',str(root/'tool/regenerate.sh')])
if args.command=='doctor':
    failed=False
    for command in [[dart,'--version'],[zig,'version'],['python3','--version'],['node','--version']]:
        try: run(command)
        except (OSError,subprocess.CalledProcessError) as error: print(error);failed=True
    validate(json.loads((root/config.get('schema','schema.json')).read_text()))
    print('Schema valid. Native execution and browser availability require separate checks.')
    sys.exit(1 if failed else 0)
elif args.command=='generate': generate()
elif args.command=='watch':
    previous=None
    try:
        while True:
            paths=[root/config.get('schema','schema.json'), *sorted((root/'zig/src').rglob('*.zig'))]
            current=tuple((str(p),p.read_bytes()) for p in paths if '/generated/' not in str(p))
            if current != previous:
                previous=current
                try: generate()
                except (ValueError,subprocess.CalledProcessError) as error: print(error,file=sys.stderr)
            time.sleep(.5)
    except KeyboardInterrupt: pass
elif args.command=='web':
    run(['sh',str(root/'tool/build_web.sh')])
    if args.run: run(['node',str(ROOT/'tool/run_web.mjs')])
elif args.command=='schema':
    source=args.source.resolve()
    result=run([zig,'run','--dep','declarations','-Mroot='+str(ROOT/'zig/src/schema_frontend.zig'),'-Mdeclarations='+str(source)],capture_output=True,text=True)
    value=json.loads(result.stderr); validate(value)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(value,indent=2)+'\n')
    print('Wrote '+str(args.output))
elif args.command=='scaffold':
    import re
    if not re.fullmatch('[a-z][a-z0-9_]*',args.name): parser.error('name must be a Dart package identifier')
    destination=args.destination.resolve()
    if destination.exists(): parser.error('destination already exists; refusing to overwrite')
    # Copy the standalone toolkit as a self-contained starting package, without caches.
    destination.mkdir(parents=True)
    for folder in ['lib','zig/src','zig/vendor','hook','web','example','authoring','tool','benchmark','doc']:
        shutil.copytree(ROOT/folder,destination/folder,ignore=shutil.ignore_patterns('__pycache__','api'))
    (destination/'bin').mkdir()
    for name in ['toolkit.dart','isolates.dart','platform_native.dart','platform_web.dart','alternate_bindings.g.dart','demo.g.dart','main.dart']:
        shutil.copyfile(ROOT/'bin'/name,destination/'bin'/name)
    for name in ['schema.json','dart_zig.json','analysis_options.yaml','.gitignore','zig/build.zig','zig/build_web.zig','zig/build.zig.zon','pubspec.yaml','README.md']:
        shutil.copyfile(ROOT/name,destination/name)
    # Regeneration creates the actual FFI declarations for this asset identity.
    for path in destination.rglob('*'):
        if path.is_file() and path.suffix in {'.dart','.sh','.py','.yaml','.json','.zon','.zig','.mjs','.html'}:
            text=path.read_text().replace('package:dart_zig/',f'package:{args.name}/')
            if path == destination/'zig/build.zig': text=text.replace('.name = "dart_zig", .linkage', '.name = "'+args.name+'", .linkage')
            if path == destination/'hook/build.dart': text=text.replace("libraryName: 'dart_zig'", "libraryName: '"+args.name+"'")
            if path.name=='pubspec.yaml': text=text.replace('name: dart_zig','name: '+args.name)
            path.write_text(text)
    print('Created '+str(destination)+'. Run dart pub get, then python3 tool/dart_zig.py generate.')
