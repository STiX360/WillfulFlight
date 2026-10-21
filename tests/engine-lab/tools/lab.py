"""Prepare isolated profiles, launch bounded tests and collect structured evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import uuid
from room import build

ROOT = Path(__file__).resolve().parents[1]
MARKER = 'ENGINE_LAB_JSON '


def lua(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        if not (-float('inf') < value < float('inf')):
            raise ValueError('Lua numeric values must be finite')
        return repr(value)
    if isinstance(value, str):
        # Fixed decimal byte escapes work in Lua 5.1, including non-ASCII text.
        return '"' + ''.join('\\%03d' % b for b in value.encode('utf-8')) + '"'
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    raise ValueError('Unsupported Lua configuration value')


def cfgpath(value):
    result = str(value).replace('\\', '/')
    if any(c in result for c in ('"', '\n', '\r')):
        raise ValueError('Invalid OpenMW config path')
    return '"' + result + '"'


def prepare(root, engine, game_data, vanilla=False):
    root = Path(root).resolve()
    engine, game_data = Path(engine).resolve(strict=True), Path(game_data).resolve(strict=True)
    config = json.loads((root / 'lab.json').read_text(encoding='utf-8'))
    config['flight_enabled'] = not vanilla
    for owner in config['owners']:
        if not isinstance(owner['disposition'], (int, float)) or not 0 <= owner['disposition'] <= 100:
            raise ValueError('Owner disposition must be in 0..100')
    for preset in config['presets'].values():
        if not isinstance(preset, (int, float)) or not 0 <= preset <= 100:
            raise ValueError('Stat preset must be in 0..100')
    resources = engine.parent / 'resources'
    actual = (resources / 'version').read_text(encoding='utf-8').splitlines()[0].strip()
    if actual != config['engine_version']:
        raise ValueError(f"Expected OpenMW {config['engine_version']}; found {actual}")
    if not re.fullmatch(r'[A-Za-z0-9 ,_-]+', config['cell']):
        raise ValueError('Lab cell must be simple ASCII text')
    for name in ('Morrowind.esm', 'Morrowind.bsa'):
        if not (game_data / name).is_file():
            raise ValueError('Missing ' + name)
    data = [(root / p).resolve() for p in config['mod_data']]
    if any(not p.is_dir() for p in data):
        raise ValueError('A configured mod data directory is missing')
    for name in config['content']:
        if not re.fullmatch(r'[^/\\\r\n"]+\.(?:esp|esm|omwaddon|omwgame|omwscripts)', name, re.I):
            raise ValueError('Invalid content filename')
        if not any((p / name).is_file() for p in [game_data, *data]):
            raise ValueError('Missing enabled content: ' + name)
    runtime = root / '.runtime'
    profile, user = runtime / 'profile', runtime / 'user-data'
    for directory in (profile, user / 'data'):
        directory.mkdir(parents=True, exist_ok=True)
    build(game_data / 'Morrowind.esm', root / 'EngineLab.esp', config['cell'])
    run_id = uuid.uuid4().hex
    config['run_id'] = run_id
    config['smoke'] = False
    (root / 'scripts/engine_lab/config.lua').write_text('return ' + lua(config) + '\n', encoding='utf-8')
    lines = ['replace=config', 'replace=data', 'replace=content', 'replace=groundcover', 'replace=fallback-archive',
             'resources=' + cfgpath(resources)]
    lines += ['data=' + cfgpath(p) for p in dict.fromkeys([resources / 'vfs-mw', game_data, *data, root])]
    lines += ['data-local=' + cfgpath(user / 'data'), 'fallback-archive=Morrowind.bsa']
    lines += ['fallback-archive=' + name for name in ('Tribunal.bsa', 'Bloodmoon.bsa') if (game_data / name).is_file()]
    lines += ['content=' + name for name in ['Morrowind.esm', *config['content'], 'EngineLab.esp', 'EngineLab.omwscripts']]
    (profile / 'openmw.cfg').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    (profile / 'settings.cfg').write_text('[Video]\nresolution x = 960\nresolution y = 640\nfullscreen = false\n', encoding='utf-8')
    state = {'engine': str(engine), 'engine_sha256': hashlib.sha256(engine.read_bytes()).hexdigest(),
             'engine_version': actual, 'profile': str(profile), 'user_data': str(user), 'run_id': run_id,
             'config': config}
    (runtime / 'prepared.json').write_text(json.dumps(state, indent=2) + '\n', encoding='utf-8')
    return state


def report(root):
    root = Path(root)
    state = json.loads((root / '.runtime/prepared.json').read_text(encoding='utf-8'))
    paths = [Path(state['user_data']) / 'openmw.log', Path(state['profile']) / 'openmw.log']
    records, errors, malformed = [], [], []
    for path in paths:
        if not path.is_file():
            continue
        for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
            if MARKER in line:
                try:
                    record = json.loads(line.split(MARKER, 1)[1])
                    if record.get('run_id') == state['run_id']:
                        records.append(record)
                except (ValueError, AttributeError):
                    malformed.append(line)
            if ' E]' in line or 'Lua error' in line or 'Error in Lua' in line:
                errors.append(line)
    assertions = [r['data'] for r in records if r['event'] == 'assertion']
    errors += [r['data'].get('detail', 'Fixture error') for r in records if r['event'] == 'error']
    ready = any(r['event'] == 'ready' for r in records)
    statuses = [a.get('status') for a in assertions]
    gameplay = ('fail' if 'fail' in statuses else 'inconclusive' if 'inconclusive' in statuses
                else 'pass' if statuses and all(s == 'pass' for s in statuses) else 'unassessed')
    result = {key: state[key] for key in ('run_id', 'engine', 'engine_version', 'engine_sha256')}
    result.update(fixture_ready=ready, assertions=assertions, gameplay_status=gameplay,
                  errors=errors, malformed=malformed, records=records)
    (root / '.runtime/report.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    return result


def run(root, smoke=False, timeout=45, allow_parallel=False):
    root = Path(root)
    state = json.loads((root / '.runtime/prepared.json').read_text(encoding='utf-8'))
    if timeout <= 0 or timeout > 60:
        raise ValueError('Timeout must be between 1 and 60 seconds')
    if hashlib.sha256(Path(state['engine']).read_bytes()).hexdigest() != state['engine_sha256']:
        raise ValueError('Engine changed after preparation; prepare a new profile')
    if os.name == 'nt' and not allow_parallel:
        output = subprocess.run(['tasklist', '/FI', 'IMAGENAME eq openmw.exe', '/FO', 'CSV', '/NH'],
                                capture_output=True, text=True, check=True).stdout
        if 'openmw.exe' in output.lower():
            raise RuntimeError('OpenMW is already running; close it or explicitly use --allow-parallel')
    config = state['config']
    state['run_id'] = config['run_id'] = uuid.uuid4().hex
    config['smoke'] = smoke
    (root / 'scripts/engine_lab/config.lua').write_text('return ' + lua(config) + '\n', encoding='utf-8')
    (root / '.runtime/prepared.json').write_text(json.dumps(state, indent=2) + '\n', encoding='utf-8')
    args = [state['engine'], '--replace', 'config', '--config', state['profile'], '--user-data', state['user_data'],
            '--skip-menu', '--new-game=0', '--start', config['cell'], '--no-grab', '--no-sound']
    startup = None
    if smoke and os.name == 'nt':
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    output = (root / '.runtime/console.log').open('w', encoding='utf-8') if smoke else None
    process = subprocess.Popen(args, cwd=str(Path(state['engine']).parent), startupinfo=startup,
                               stdout=output, stderr=subprocess.STDOUT if smoke else None)
    if not smoke:
        print('Interactive lab PID:', process.pid)
        return None
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        raise RuntimeError('Fixture smoke timed out; inspect the isolated log')
    finally:
        if output: output.close()
    result = report(root)
    expected = config.get('expected_probe_results')
    if expected and (sum(r['event'] == 'probe' for r in result['records']) != expected
                     or not any(r['event'] == 'probe_complete' and r['data'].get('count') == expected
                                for r in result['records'])):
        raise RuntimeError('Native probes did not all respond; inspect .runtime/report.json')
    if (process.returncode or not result['fixture_ready'] or result['errors'] or result['malformed']
            or result['gameplay_status'] != 'pass' or len(result['assertions']) != config.get('expected_cases',8)
            or not any(r['event'] == 'flight_complete' for r in result['records'])):
        raise RuntimeError('Fixture smoke failed; inspect .runtime/report.json')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    prepare_args = commands.add_parser('prepare')
    prepare_args.add_argument('--engine', required=True)
    prepare_args.add_argument('--game-data', required=True)
    prepare_args.add_argument('--vanilla', action='store_true')
    run_args = commands.add_parser('run')
    run_args.add_argument('--smoke', action='store_true')
    run_args.add_argument('--timeout', type=int, default=45)
    run_args.add_argument('--allow-parallel', action='store_true')
    commands.add_parser('report')
    args = vars(parser.parse_args())
    command = args.pop('command')
    result = {'prepare': prepare, 'run': run, 'report': report}[command](ROOT, **args)
    if result is not None:
        print(json.dumps(result, indent=2))
