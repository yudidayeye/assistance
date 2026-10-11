import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[2] / 'scripts/ci_release.py'
spec = importlib.util.spec_from_file_location('ci_release', MODULE)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseGuardTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.old_dir = Path.cwd()
        os.chdir(self.repo)
        self.git('init', '-b', 'master')
        self.git('config', 'user.name', 'Release Test')
        self.git('config', 'user.email', 'release-test@example.invalid')
        Path('pubspec.yaml').write_text('name: example\n# 中文\nversion: 1.2.10+39\n', encoding='utf-8')
        self.git('add', 'pubspec.yaml')
        self.git('commit', '-m', 'fixture')
        self.source = self.git('rev-parse', 'HEAD')
        subprocess.run(['git', 'init', '--bare', str(self.root / 'remote')], check=True, capture_output=True)
        self.git('remote', 'add', 'origin', str(self.root / 'remote'))
        self.git('push', 'origin', 'master')
        self.output = self.root / 'output'
        self.env = patch.dict(os.environ, {'GITHUB_OUTPUT': str(self.output)})
        self.env.start()

    def tearDown(self):
        self.env.stop()
        os.chdir(self.old_dir)
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', *args], text=True, stderr=subprocess.DEVNULL).strip()

    def manifests(self):
        root = Path('release-assets')
        root.mkdir()
        for platform, names in [('android', release.APK_NAMES), ('windows', ['my_assistant_setup_1.2.11.exe'])]:
            for name in names:
                (root / name).write_bytes(name.encode())
            release.manifest(platform, '1.2.11', 40, root, names)
        return root

    def test_new_plan_does_not_create_commit_tag_or_change_version(self):
        release.plan('1.2.11', 'new')
        self.assertIn('build=40\n', self.output.read_text())
        self.assertIn(f'ref={self.source}\n', self.output.read_text())
        self.assertEqual(self.git('rev-parse', 'HEAD'), self.source)
        self.assertEqual(release.current(), ('1.2.10', 39))
        self.assertEqual(self.git('tag'), '')
        self.assertEqual(self.git('status', '--porcelain'), '')

    def test_new_plan_refuses_same_or_lower_version(self):
        for value in ['1.2.10', '1.2.9', '1.2.11;echo bad']:
            with self.assertRaises(ValueError):
                release.plan(value, 'new')
        self.assertFalse(self.output.exists())

    def test_new_plan_refuses_existing_remote_tag(self):
        self.git('tag', 'v1.2.11')
        self.git('push', 'origin', 'v1.2.11')
        with self.assertRaisesRegex(ValueError, '标签已存在'):
            release.plan('1.2.11', 'new')

    def test_existing_uses_original_tag_build_number(self):
        self.git('tag', 'v1.2.10')
        self.git('push', 'origin', 'v1.2.10')
        Path('readme').write_text('later commit')
        self.git('add', 'readme')
        self.git('commit', '-m', 'later')
        real_run = release.run
        with patch.object(release, 'run', side_effect=lambda *args: '{}' if args[0]=='gh' else real_run(*args)):
            release.plan('1.2.10', 'existing')
        self.assertIn('build=39\n', self.output.read_text())
        self.assertIn(f'ref={self.source}\n', self.output.read_text())

    def test_publish_rejects_corrupted_artifact_before_any_write(self):
        root = self.manifests()
        (root / release.APK_NAMES[0]).write_bytes(b'corrupted')
        with patch.object(subprocess, 'check_call', side_effect=AssertionError('Unexpected mutation')):
            with self.assertRaisesRegex(ValueError, '校验失败'):
                release.publish('1.2.11', '40', 'new', self.source)
        self.assertEqual(self.git('rev-parse', 'HEAD'), self.source)
        self.assertEqual(self.git('tag'), '')

    def test_publish_refuses_platforms_built_from_different_source(self):
        root = self.manifests()
        p = root / 'manifest-windows.json'
        data = json.loads(p.read_text())
        data['source'] = '0' * 40
        p.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, '源码不一致'):
            release.publish('1.2.11', '40', 'new', self.source)

    def test_publish_does_not_overwrite_master_advanced_during_build(self):
        self.manifests()
        Path('another-change').write_text('concurrent update')
        self.git('add', 'another-change')
        self.git('commit', '-m', 'concurrent')
        remote_head = self.git('rev-parse', 'HEAD')
        self.git('push', 'origin', 'master')
        self.git('reset', '--hard', self.source)
        with self.assertRaisesRegex(ValueError, 'master 已变化'):
            release.publish('1.2.11', '40', 'new', self.source)
        self.assertIn(remote_head, self.git('ls-remote', 'origin', 'refs/heads/master'))
        self.assertEqual(self.git('tag'), '')


if __name__ == '__main__':
    unittest.main()
