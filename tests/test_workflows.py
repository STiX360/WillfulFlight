import json
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.workflow = yaml.load(
            (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8'),
            Loader=yaml.BaseLoader,
        )

    def test_tag_publishing_and_build_only_dispatch(self):
        self.assertEqual(self.workflow['on']['push']['tags'], ['v*'])
        self.assertIn('workflow_dispatch', self.workflow['on'])
        for name in ('github-release', 'nexus'):
            condition = self.workflow['jobs'][name]['if']
            self.assertIn("github.event_name == 'push'", condition)
            self.assertIn('!github.event.deleted', condition)
        self.assertIn("vars.NEXUSMODS_ENABLED == 'true'", self.workflow['jobs']['nexus']['if'])

    def test_nexus_waits_for_github_and_uses_production_artifact(self):
        jobs = self.workflow['jobs']
        self.assertEqual(jobs['nexus']['needs'], ['build', 'github-release'])
        self.assertEqual(jobs['nexus']['environment'], 'nexus')
        self.assertEqual(jobs['github-release']['permissions']['contents'], 'write')
        self.assertEqual(self.workflow['permissions']['contents'], 'read')
        for name in ('github-release', 'nexus'):
            steps = jobs[name]['steps']
            download = next(s for s in steps if s.get('uses', '').startswith('actions/download-artifact@'))
            self.assertEqual(download['with'], {'name': 'release-package', 'path': 'dist'})
            self.assertFalse(any(s.get('run') == 'python tools/release.py package' for s in steps))
            self.assertTrue(any(s.get('with', {}).get('python-version') == '3.12' for s in steps))
        upload = next(s for s in jobs['nexus']['steps'] if s.get('id') == 'upload')
        self.assertRegex(upload['uses'], r'^Nexus-Mods/upload-action@[0-9a-f]{40}$')
        self.assertEqual(upload['with']['filename'], 'dist/${{ needs.build.outputs.filename }}')
        self.assertEqual(upload['with']['api_key'], '${{ secrets.NEXUSMODS_API_KEY }}')
        self.assertEqual(upload['with']['archive_existing_version'], 'false')

    def test_package_is_only_the_mod_and_normal_release(self):
        config = json.loads((ROOT / 'release/config.json').read_text(encoding='utf-8'))
        self.assertFalse(config['prerelease'])
        self.assertEqual(set(config['files'].values()), {
            'WillfulFlight.omwscripts',
            'scripts/willful_flight/global.lua',
            'scripts/willful_flight/player.lua',
            'scripts/willful_flight/policy.lua',
            'l10n/WillfulFlight/en.yaml',
        })

    def test_public_launchers_have_no_workstation_specific_paths(self):
        for name in ('test-game.ps1', 'start-test.ps1'):
            source = (ROOT / 'tools' / name).read_text(encoding='utf-8')
            self.assertNotIn('C:\\Modlists', source)
            self.assertNotIn('D:\\Steam', source)
            self.assertIn('$env:OPENMW_EXE', source)


if __name__ == '__main__':
    unittest.main()
