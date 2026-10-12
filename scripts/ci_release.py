"""手动 Actions 发布的版本规划、签名与产物校验；由发布脚本调用。"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

OLD_CERT = 'c82e8fdbb18885ba841914d22e5d8ede4b40f66ba78f29991db0e3ca0a4a923d'
APK_NAMES = ['app-armeabi-v7a-release.apk', 'app-arm64-v8a-release.apk', 'app-x86_64-release.apk']


def run(*args):
    return subprocess.check_output(args, text=True, encoding='utf-8').strip()


def version(value):
    if not re.fullmatch(r'\d+\.\d+\.\d+', value):
        raise ValueError('版本号必须为 x.y.z')
    return tuple(map(int, value.split('.')))


def current(text=None):
    text = Path('pubspec.yaml').read_text(encoding='utf-8') if text is None else text
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', text, re.M)
    if not match:
        raise ValueError('pubspec.yaml 缺少版本或构建号')
    return match.group(1), int(match.group(2))


def set_version(v, build):
    version(v)
    if not 0 < int(build) < 1000:
        raise ValueError('构建号必须为 1..999，与现有 ABI versionCode 规则一致')
    p = Path('pubspec.yaml')
    current(p.read_text(encoding='utf-8'))
    p.write_text(re.sub(r'^version:.*$', f'version: {v}+{build}', p.read_text(encoding='utf-8'), flags=re.M), encoding='utf-8')


def plan(v, mode):
    version(v)
    tag = 'v' + v
    if mode == 'existing':
        subprocess.check_call(['git', 'fetch', 'origin', f'refs/tags/{tag}:refs/tags/{tag}'])
        ref = run('git', 'rev-parse', f'{tag}^{{commit}}')
        actual, build = current(run('git', 'show', f'{ref}:pubspec.yaml'))
        if actual != v:
            raise ValueError('标签与源码版本不一致')
        run('gh', 'release', 'view', tag, '--json', 'url')
    elif mode == 'new':
        actual, build = current()
        if version(v) <= version(actual):
            raise ValueError('新版本必须高于 master 当前版本；修复同版本请选择 existing')
        if run('git', 'ls-remote', 'origin', f'refs/tags/{tag}'):
            raise ValueError('标签已存在，请选择 existing 或更换新版本号')
        build += 1
        ref = run('git', 'rev-parse', 'HEAD')
    else:
        raise ValueError('未知发布模式')
    if not 0 < build < 1000:
        raise ValueError('构建号超出当前 ABI 编码范围')
    with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
        f.write(f'version={v}\nbuild={build}\nref={ref}\nmode={mode}\n')


def tools():
    sdk = Path(os.environ['ANDROID_HOME'])
    candidates = sorted((sdk / 'build-tools').glob('*/apksigner'))
    if not candidates:
        raise ValueError('找不到 Android Build Tools')
    return candidates[-1].parent


def android(v, build):
    directory = Path('build/app/outputs/flutter-apk')
    expected = os.environ.get('ANDROID_SIGNING_CERT_SHA256') or OLD_CERT
    expected = expected.replace(':', '').lower()
    if not re.fullmatch(r'[a-f0-9]{64}', expected):
        raise ValueError('预期签名 SHA-256 配置无效')
    tool = tools()
    for name in APK_NAMES:
        p = directory / name
        signed = p.with_suffix('.signed.apk')
        subprocess.check_call([str(tool / 'apksigner'), 'sign', '--ks', os.environ['CI_KEYSTORE_PATH'],
            '--ks-key-alias', os.environ['ANDROID_KEY_ALIAS'], '--ks-pass', 'env:ANDROID_KEYSTORE_PASSWORD',
            '--key-pass', 'env:ANDROID_KEY_PASSWORD', '--out', str(signed), str(p)])
        cert = run(str(tool / 'apksigner'), 'verify', '--print-certs', str(signed))
        match = re.search(r'certificate SHA-256 digest: ([a-f0-9]+)', cert)
        if not match or match.group(1) != expected:
            raise ValueError('签名证书不符合预期；已停止上传，避免破坏覆盖升级能力')
        signed.replace(p)
        badging = run(str(tool / 'aapt2'), 'dump', 'badging', str(p))
        name_match = re.search(r"versionName='([^']+)'", badging)
        code_match = re.search(r"versionCode='(\d+)'", badging)
        if not name_match or name_match.group(1) != v or not code_match or int(code_match.group(1)) % 1000 != int(build):
            raise ValueError('APK 内嵌版本不匹配')
    manifest('android', v, build, directory, APK_NAMES)


def manifest(platform, v, build, directory, names):
    data = {'platform': platform, 'version': v, 'build': int(build), 'source': run('git', 'rev-parse', 'HEAD'),
        'files': [{'name': n, 'size': (directory / n).stat().st_size,
                   'sha256': hashlib.sha256((directory / n).read_bytes()).hexdigest()} for n in names]}
    (directory / f'manifest-{platform}.json').write_text(json.dumps(data), encoding='utf-8')


def publish(v, build, mode, source):
    version(v)
    if mode not in ('new', 'existing'):
        raise ValueError('未知发布模式')
    tag = 'v' + v
    root = Path('release-assets')
    manifests = [json.loads((root / f'manifest-{p}.json').read_text(encoding='utf-8')) for p in ('android', 'windows')]
    expected_names = set(APK_NAMES + [f'my_assistant_setup_{v}.exe'])
    files = [f for m in manifests for f in m['files']]
    if len(files) != 4 or {f['name'] for f in files} != expected_names:
        raise ValueError('必须同时具备三个 APK 和一个 Windows 安装包')
    for m in manifests:
        if (m['version'], m['build'], m['source']) != (v, int(build), source):
            raise ValueError('两个平台的版本、构建号或源码不一致')
    for f in files:
        p = root / f['name']
        if p.stat().st_size != f['size'] or hashlib.sha256(p.read_bytes()).hexdigest() != f['sha256']:
            raise ValueError('下载的构建产物校验失败')
    if mode == 'new':
        if run('git', 'rev-parse', 'HEAD') != source or run('git', 'ls-remote', 'origin', 'refs/heads/master').split()[0] != source:
            raise ValueError('构建期间 master 已变化，请重新运行，不覆盖其他提交')
        if run('git', 'ls-remote', 'origin', f'refs/tags/{tag}'):
            raise ValueError('版本标签已存在，停止新版本发布')
        set_version(v, build)
        subprocess.check_call(['git', 'add', 'pubspec.yaml'])
        subprocess.check_call(['git', 'commit', '-m', f'chore: 发布 {tag}'])
        subprocess.check_call(['git', 'tag', tag])
        subprocess.check_call(['git', 'push', '--atomic', 'origin', 'HEAD:refs/heads/master', f'refs/tags/{tag}'])
        notes = os.environ.get('RELEASE_NOTES', '')
        with tempfile.NamedTemporaryFile('w', delete=False) as f:
            f.write(notes)
            notes_path = f.name
        try:
            args = ['gh', 'release', 'create', tag, '--draft', '--verify-tag', '--title', tag]
            args += ['--notes-file', notes_path] if notes else ['--generate-notes']
            subprocess.check_call(args)
        finally:
            Path(notes_path).unlink()
    else:
        if run('git', 'rev-parse', f'{tag}^{{commit}}') != source:
            raise ValueError('原版本标签发生变化，停止替换附件')
        run('gh', 'release', 'view', tag, '--json', 'url')
    repo = os.environ['GH_REPO']
    # 草稿不能通过 releases/tags 查询；列表定位后使用稳定的数字 ID。
    release_id = run('gh', 'api', f'repos/{repo}/releases', '--paginate', '--jq',
        f'.[] | select(.tag_name == "{tag}") | .id')
    if not release_id.isdigit():
        raise ValueError('无法唯一定位目标 Release，停止发布')
    endpoint = f'repos/{repo}/releases/{release_id}'
    release = json.loads(run('gh', 'api', endpoint))

    def matches(asset, expected):
        return (asset is not None and asset.get('state') == 'uploaded'
            and asset.get('size') == expected['size']
            and asset.get('digest') == 'sha256:' + expected['sha256'])

    assets = {a['name']: a for a in release['assets']}
    pending = [f for f in files if not matches(assets.get(f['name']), f)]
    if pending:
        subprocess.check_call(['gh', 'release', 'upload', tag, '--clobber',
            *[str(root / f['name']) for f in pending]])
        release = json.loads(run('gh', 'api', endpoint))
        assets = {a['name']: a for a in release['assets']}
    if any(not matches(assets.get(f['name']), f) for f in files):
        raise ValueError('GitHub 上传产物校验失败；未执行公开发布步骤')
    subprocess.check_call(['gh', 'release', 'edit', tag, '--draft=false', '--latest'])
    print(run('gh', 'release', 'view', tag, '--json', 'url', '--jq', '.url'))


if __name__ == '__main__':
    commands = {'plan': plan, 'set-version': set_version, 'android': android, 'publish': publish,
        'windows': lambda v, b: manifest('windows', v, b, Path('build/windows/installer'), [f'my_assistant_setup_{v}.exe'])}
    try:
        commands[sys.argv[1]](*sys.argv[2:])
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f'::error::{error}', file=sys.stderr)
        sys.exit(1)
