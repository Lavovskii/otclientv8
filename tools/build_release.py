#!/usr/bin/env python3
"""Builds a client release: dist/data.zip (everything the client runs from, but the game graphics), the update
manifest and files the launcher (modules/updater) compares itself with, the installer, and publishes them.

  python tools/build_release.py              data.zip, dist/updater and dist/things-version.txt
  python tools/build_release.py --installer  ... and dist/ForgottenL-Client-Setup.exe (Inno Setup)
  python tools/build_release.py --publish    ... and puts dist/updater on the website (ssh alias "vps")

The installed client reads data.zip from its folder, or the newer one an update wrote into the user's folder
(AppData/OTClientV8/ForgottenL). The game graphics (data/things/860, 420 MB) stay out of data.zip: the installer puts
them in the user's folder with version.txt next to them. For the updates they are cut into zipped parts
(dist/graphics/<version>, about 100 MB, published once per graphics version): when their version changes the launcher
downloads the parts and writes the files itself. Any change, graphics too, only needs --publish: every client updates
itself at its next start or login and restarts. Raise CLIENT_BUILD in init.lua with every release and set the
server's minClientBuild to it: the login and the game refuse older builds, so nobody plays an old client (one that
never asked, or could not reach the website).
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
DIST = os.path.join(ROOT, 'dist')
ISS = os.path.join(ROOT, 'installer', 'forgottenl-client.iss')
ISCC = os.environ.get('ISCC', os.path.expanduser(r'~\AppData\Local\Programs\Inno Setup 6\ISCC.exe'))
THINGS = '860'
SITE = 'https://forgottenl.me/downloads'
REMOTE = '/var/www/forgl-downloads/updater'
REMOTE_GRAPHICS = '/var/www/forgl-downloads/graphics'
PACKED = ['init.lua', 'data', 'modules', 'layouts', 'mods']
# the game graphics are cut into parts of this many bytes, each zipped on its own (about 3 MB): the client holds a
# download in memory, so a part has to stay small, and the launcher writes each one into the file as it arrives
GRAPHICS_PART = 6 << 20


def crc(path):
    value = 0
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            value = zlib.crc32(chunk, value)
    return '%08x' % (value & 0xffffffff)


def packed_files():
    """the client's files as data.zip names (no data/things)"""
    names = []
    for top in PACKED:
        path = os.path.join(ROOT, top)
        if os.path.isfile(path):
            names.append(top)
            continue
        for folder, dirs, files in os.walk(path):
            rel = os.path.relpath(folder, ROOT).replace(os.sep, '/')
            if rel == 'data/things' or rel.startswith('data/things/'):
                dirs[:] = []
                continue
            dirs[:] = [d for d in dirs if d != '__pycache__']
            names += [rel + '/' + f for f in files if not f.endswith('.pyc')]
    return sorted(names)


def check_lua(names):
    """every Lua file compiles with LuaJIT 2.1 (the client's Lua): a broken updater.lua would stop every client at
    startup, before it could fetch the fix"""
    from lupa.luajit21 import LuaRuntime
    compile_lua = LuaRuntime().eval('function(source, name) local f, err = loadstring(source, name) return err end')
    errors = []
    for name in names:
        if name.endswith('.lua'):
            err = compile_lua(open(os.path.join(ROOT, name), 'rb').read(), '@' + name)
            if err:
                errors.append(err)
    if errors:
        sys.exit('Lua errors, nothing built:\n' + '\n'.join(errors))


def graphics_parts(things, version):
    """the game graphics as zipped parts (dist/graphics/<version>, one entry "part" per zip, the same bytes at every
    build) and their list for the manifest: [{name, size, parts: [{file, checksum, size}]}]; made once per version"""
    out = os.path.join(DIST, 'graphics', version)
    listing = os.path.join(out, 'parts.json')
    if os.path.isfile(listing):
        return json.load(open(listing))
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    files = []
    for name in ('Tibia.dat', 'Tibia.spr'):
        parts = []
        with open(os.path.join(things, name), 'rb') as f:
            for chunk in iter(lambda: f.read(GRAPHICS_PART), b''):
                part = '%s.%03d.zip' % (name, len(parts))
                with zipfile.ZipFile(os.path.join(out, part), 'w') as z:
                    z.writestr(zipfile.ZipInfo('part', date_time=(1980, 1, 1, 0, 0, 0)), chunk,
                               compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
                parts.append({'file': part, 'checksum': crc(os.path.join(out, part)), 'size': len(chunk)})
        files.append({'name': name, 'size': sum(p['size'] for p in parts), 'parts': parts})
    with open(listing, 'w', newline='\n') as f:
        json.dump(files, f, indent=1)
    return files


def main():
    version = re.search(r'#define MyAppVersion "([^"]+)"', open(ISS, encoding='utf-8').read()).group(1)
    build = int(re.search(r'^CLIENT_BUILD = (\d+)', open(os.path.join(ROOT, 'init.lua'), encoding='utf-8').read(), re.M).group(1))
    os.makedirs(DIST, exist_ok=True)
    names = packed_files()
    check_lua(names)

    with zipfile.ZipFile(os.path.join(DIST, 'data.zip'), 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in names:
            z.write(os.path.join(ROOT, name), name)

    updater = os.path.join(DIST, 'updater')
    shutil.rmtree(updater, ignore_errors=True)
    files = {}
    for name in names:
        target = os.path.join(updater, 'files', name)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copyfile(os.path.join(ROOT, name), target)
        files['/' + name] = crc(target)

    things = os.path.join(ROOT, 'data', 'things', THINGS)
    things_version = '%s-%s-%s' % (THINGS, crc(os.path.join(things, 'Tibia.dat')), crc(os.path.join(things, 'Tibia.spr')))
    open(os.path.join(DIST, 'things-version.txt'), 'w', newline='\n').write(things_version + '\n')
    graphics = graphics_parts(things, things_version)

    # "graphics", not the old "things": the launchers of 1.0.6 and 1.0.7 sent the player to the installer when the
    # "things" version changed; without it they take the update of the Lua files, and the new launcher they get then
    # downloads the graphics by itself
    manifest = {
        'version': '%s build %d' % (version, build),
        'build': build,
        'url': SITE + '/updater/files',
        'installer': SITE + '/ForgottenL-Client-Setup.exe',
        'graphics': {'folder': THINGS, 'version': things_version, 'url': SITE + '/graphics/' + things_version + '/',
                     'files': graphics},
        'files': files,
    }
    with open(os.path.join(updater, 'manifest.json'), 'w', newline='\n') as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    print('client %s build %d: %d files, data.zip %d KB, graphics %s' % (version, build, len(files),
          os.path.getsize(os.path.join(DIST, 'data.zip')) // 1024, things_version))

    if '--installer' in sys.argv:
        subprocess.run([ISCC, '/Q', ISS], check=True, env=dict(os.environ, MSYS_NO_PATHCONV='1'))
        print('installer', os.path.join(DIST, 'ForgottenL-Client-Setup.exe'))

    if '--publish' in sys.argv:
        # the graphics parts first (only when this version is not on the website yet), so the manifest never names a
        # part not there; "complete" marks a finished upload
        target = '%s/%s' % (REMOTE_GRAPHICS, things_version)
        if subprocess.run(['ssh', 'vps', 'test -f %s/complete' % target]).returncode != 0:
            remote = ('set -e; G=%s; sudo rm -rf $G.new; sudo mkdir -p $G.new; sudo tar -xf - -C $G.new --no-same-owner; '
                      'sudo touch $G.new/complete; sudo chmod -R a+rX %s; sudo rm -rf $G; sudo mv $G.new $G; '
                      'echo published graphics $(ls $G | grep -c zip) parts' % (target, REMOTE_GRAPHICS))
            ssh = subprocess.Popen(['ssh', 'vps', remote], stdin=subprocess.PIPE)
            with tarfile.open(fileobj=ssh.stdin, mode='w|') as tar:
                for f in graphics:
                    for part in f['parts']:
                        tar.add(os.path.join(DIST, 'graphics', things_version, part['file']), part['file'])
            ssh.stdin.close()
            if ssh.wait() != 0:
                sys.exit('publish of the graphics failed')
        # the whole folder goes up and replaces the old one at once, so a manifest never names a file not there yet
        remote = ('set -e; D=%s; sudo rm -rf $D.new $D.old; sudo mkdir -p $D.new; sudo tar -xf - -C $D.new --no-same-owner; '
                  'sudo chmod -R a+rX $D.new; if [ -d $D ]; then sudo mv $D $D.old; fi; sudo mv $D.new $D; sudo rm -rf $D.old; '
                  'echo published $(find $D/files -type f | wc -l) files' % REMOTE)
        ssh = subprocess.Popen(['ssh', 'vps', remote], stdin=subprocess.PIPE)
        with tarfile.open(fileobj=ssh.stdin, mode='w|') as tar:
            tar.add(os.path.join(updater, 'files'), 'files')
            tar.add(os.path.join(updater, 'manifest.json'), 'manifest.json')
        ssh.stdin.close()
        if ssh.wait() != 0:
            sys.exit('publish failed')
        print('now set minClientBuild = %d in the server config.lua (and restart it) so older clients are refused' % build)


if __name__ == '__main__':
    main()
