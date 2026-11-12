#!/usr/bin/env python3

import argparse
import datetime
import os
import plistlib
import subprocess
import tempfile
import uuid


def run_openssl(arguments, input_data=None):
    return subprocess.run(
        ['openssl'] + arguments,
        input=input_data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    ).stdout


def main():
    parser = argparse.ArgumentParser(description='Create a fake local profile for an unsigned Sideloadly build.')
    parser.add_argument('--source-profile', required=True)
    parser.add_argument('--certificate', required=True)
    parser.add_argument('--bundle-id', required=True)
    parser.add_argument('--team-id', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()

    profile_data = run_openssl([
        'smime', '-inform', 'der', '-verify', '-noverify', '-in', args.source_profile,
    ])
    profile = plistlib.loads(profile_data)

    now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
    certificate_pem = run_openssl([
        'pkcs12', '-legacy', '-in', args.certificate, '-clcerts', '-nokeys', '-passin', 'pass:',
    ])
    private_key_pem = run_openssl([
        'pkcs12', '-legacy', '-in', args.certificate, '-nocerts', '-nodes', '-passin', 'pass:',
    ])
    certificate_der = run_openssl(['x509', '-outform', 'der'], input_data=certificate_pem)

    entitlements = profile.setdefault('Entitlements', {})
    entitlements['application-identifier'] = args.team_id + '.' + args.bundle_id
    entitlements['com.apple.developer.team-identifier'] = args.team_id
    entitlements['com.apple.security.application-groups'] = ['group.' + args.bundle_id]
    entitlements['keychain-access-groups'] = [args.team_id + '.*']
    entitlements['aps-environment'] = 'development'

    profile['ApplicationIdentifierPrefix'] = [args.team_id]
    profile['TeamIdentifier'] = [args.team_id]
    profile['DeveloperCertificates'] = [certificate_der]
    profile['CreationDate'] = now
    profile['ExpirationDate'] = now + datetime.timedelta(days=365)
    profile['UUID'] = str(uuid.uuid4()).upper()
    profile['Name'] = 'FlexGram Unsigned CI Profile'
    profile['Platform'] = ['iOS']
    profile.pop('ProvisionsAllDevices', None)
    profile['ProvisionedDevices'] = []

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with tempfile.TemporaryDirectory() as temp_dir:
        payload_path = os.path.join(temp_dir, 'profile.plist')
        cert_path = os.path.join(temp_dir, 'certificate.pem')
        key_path = os.path.join(temp_dir, 'private-key.pem')
        with open(payload_path, 'wb') as payload:
            payload.write(plistlib.dumps(profile, fmt=plistlib.FMT_XML, sort_keys=True))
        with open(cert_path, 'wb') as cert:
            cert.write(certificate_pem)
        with open(key_path, 'wb') as key:
            key.write(private_key_pem)
        run_openssl([
            'smime', '-sign', '-binary', '-nodetach', '-in', payload_path,
            '-out', args.output, '-outform', 'der', '-signer', cert_path,
            '-inkey', key_path, '-passin', 'pass:',
        ])


if __name__ == '__main__':
    main()
