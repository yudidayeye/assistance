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

    def test_new_release_uses_create_response_id_without_querying_draft_list(self):
        root = self.manifests()
        files = [f for p in ('android', 'windows')
            for f in json.loads((root / f'manifest-{p}.json').read_text())['files']]
        real_run = release.run
        uploaded = False
        calls = []
        def command(args):
            nonlocal uploaded
            if args[0] == 'git':
                subprocess.run(args, check=True, capture_output=True)
                return
            calls.append(args)
            if args[:3] == ['gh','release','upload']:
                uploaded = True
        def output(*args):
            if args[0] != 'gh':
                return real_run(*args)
            if args[:3] == ('gh','release','view'):
                return 'https://example.com/release'
            if args[2] == 'repos/example/repo/releases':
                self.assertIn('--method', args)
                self.assertIn('POST', args)
                payload = json.loads(Path(args[-1]).read_text())
                self.assertEqual(payload, {'tag_name':'v1.2.11','name':'v1.2.11','draft':True,'body':'发布说明'})
                return json.dumps({'id':123})
            self.assertEqual(args[2], 'repos/example/repo/releases/123')
            assets = [{**f,'state':'uploaded','digest':'sha256:'+f['sha256']} for f in files] if uploaded else []
            return json.dumps({'tag_name':'v1.2.11','assets':assets,'html_url':'https://example.com/release'})
        with patch.dict(os.environ, {'GH_REPO':'example/repo','RELEASE_NOTES':'发布说明'}), \
             patch.object(release,'run',side_effect=output), \
             patch.object(subprocess,'check_call',side_effect=command):
            release.publish('1.2.11','40','new',self.source)
        self.assertEqual(release.current(), ('1.2.11',40))
        self.assertEqual(calls[0][:5], ['gh','release','upload','v1.2.11','--clobber'])
        self.assertEqual(calls[-1], ['gh','release','edit','v1.2.11','--draft=false','--latest'])

    def test_existing_draft_uses_release_id_and_resumes_without_reuploading_matching_assets(self):
        release.set_version('1.2.11', 40)
        self.git('add', 'pubspec.yaml')
        self.git('commit', '-m', 'release version')
        self.source = self.git('rev-parse', 'HEAD')
        self.git('tag', 'v1.2.11')
        root = self.manifests()
        files = [f for platform in ('android', 'windows')
            for f in json.loads((root / f'manifest-{platform}.json').read_text())['files']]
        real_run = release.run
        for changed in (False, True):
            with self.subTest(changed=changed):
                calls = []
                uploaded = False
                def command(args):
                    nonlocal uploaded
                    self.assertEqual(args[0], 'gh')
                    calls.append(args)
                    if args[:3] == ['gh', 'release', 'upload']:
                        uploaded = True
                def output(*args):
                    if args[0] != 'gh':
                        return real_run(*args)
                    if args[:3] == ('gh', 'release', 'view'):
                        return '{}'
                    if args[2] == 'graphql':
                        return json.dumps({'data':{'repository':{'release':{'databaseId':123}}}})
                    self.assertEqual(args[2], 'repos/example/repo/releases/123')
                    assets = [{**f, 'state':'uploaded', 'digest':'sha256:' + f['sha256']} for f in files]
                    if changed and not uploaded:
                        assets[0]['digest'] = 'sha256:' + '0' * 64
                    return json.dumps({'tag_name':'v1.2.11', 'assets':assets, 'html_url':'https://example.com/release'})
                with patch.dict(os.environ, {'GH_REPO':'example/repo'}), \
                     patch.object(release, 'run', side_effect=output), \
                     patch.object(subprocess, 'check_call', side_effect=command):
                    release.publish('1.2.11', '40', 'existing', self.source)
                self.assertEqual(calls[-1], ['gh','release','edit','v1.2.11','--draft=false','--latest'])
                self.assertEqual(len(calls), 2 if changed else 1)
                if changed:
                    self.assertEqual(calls[0][-1], str(root / files[0]['name']))
                    self.assertEqual(len(calls[0]), 6)

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
