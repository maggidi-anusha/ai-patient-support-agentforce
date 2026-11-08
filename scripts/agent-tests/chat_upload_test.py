"""End-to-end test of the AI Patient Support Agent through its Enhanced Chat channel.

Starts an anonymous chat, answers the agent's questions with fictional details,
uploads a fictional PDF report, types "done", and prints the agent's replies.

Usage:
  python3 scripts/agent-tests/chat_upload_test.py <org_id> <scrt_url> <deployment_api_name> <origin> <pdf_path>

Example values come from the org: the SCRT URL ends in .salesforce-scrt.com, and the
origin is one of the org's CORS-allowed domains. Uses fictional data only.
"""
import json
import sys
import time
import urllib.error
import urllib.request
import uuid

ORG, SCRT, DEPLOYMENT, ORIGIN, PDF = sys.argv[1:6]
DETAILS = ['Hi', 'Rohan Test', '29', 'Male', 'rohan.test@example.com', '5550100']


def call(path, data=None, token=None, raw=None, content_type='application/json'):
    headers = {'Origin': ORIGIN}
    if content_type:
        headers['Content-Type'] = content_type
    if token:
        headers['Authorization'] = 'Bearer ' + token
    body = raw if raw is not None else (json.dumps(data).encode() if data is not None else None)
    request = urllib.request.Request(SCRT + path, data=body, headers=headers,
                                     method='POST' if body is not None else 'GET')
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()


status, body = call('/iamessage/v1/authorization/unauthenticated/accessToken', {
    'orgId': ORG, 'developerName': DEPLOYMENT, 'capabilitiesVersion': '260',
    'deviceId': str(uuid.uuid4())})
token = json.loads(body)['accessToken']
conversation_id = str(uuid.uuid4())
print('conversation', call('/iamessage/v1/conversation',
                           {'conversationId': conversation_id, 'language': 'en_US'}, token)[0])
seen = set()


def agent_replies(wait_seconds):
    deadline = time.time() + wait_seconds
    replies = []
    while time.time() < deadline:
        time.sleep(4)
        status, body = call('/iamessage/api/v2/conversation/%s/entries?limit=40' % conversation_id,
                            token=token)
        if status >= 300:
            continue
        for entry in reversed(json.loads(body).get('conversationEntries', [])):
            key = entry.get('identifier') or entry.get('id') or json.dumps(entry.get('entryPayload'))[:80]
            if key in seen:
                continue
            seen.add(key)
            if entry.get('entryType') == 'Message' and (entry.get('sender') or {}).get('role') != 'EndUser':
                payload = entry.get('entryPayload')
                payload = json.loads(payload) if isinstance(payload, str) else (payload or {})
                text = ((payload.get('abstractMessage') or {}).get('staticContent') or {}).get('text') or ''
                if text:
                    replies.append(text)
        if replies and wait_seconds < 60:
            break
    return replies


def say(text, wait_seconds=40):
    status, _ = call('/iamessage/api/v2/conversation/%s/message' % conversation_id, {
        'message': {'id': str(uuid.uuid4()), 'messageType': 'StaticContentMessage',
                    'staticContent': {'formatType': 'Text', 'text': text}},
        'esDeveloperName': DEPLOYMENT, 'isNewMessagingSession': False, 'language': 'en_US'}, token)
    print('\n>>> USER:', text, '(HTTP %s)' % status, flush=True)
    for reply in agent_replies(wait_seconds):
        print('AGENT:', reply, flush=True)


agent_replies(10)
for detail in DETAILS:
    say(detail)

boundary = '----' + uuid.uuid4().hex
entry = json.dumps({'esDeveloperName': DEPLOYMENT,
                    'message': {'id': str(uuid.uuid4()), 'fileId': str(uuid.uuid4()), 'text': ''}})
file_name = PDF.rsplit('/', 1)[-1]
body = (f'--{boundary}\r\nContent-Disposition: form-data; name="messageEntry"\r\n'
        f'Content-Type: application/json\r\n\r\n{entry}\r\n--{boundary}\r\n'
        f'Content-Disposition: form-data; name="fileData"; filename="{file_name}"\r\n'
        f'Content-Type: application/pdf\r\n\r\n').encode() + open(PDF, 'rb').read() + f'\r\n--{boundary}--\r\n'.encode()
status, _ = call('/iamessage/api/v2/conversation/%s/file' % conversation_id, raw=body, token=token,
                 content_type='multipart/form-data; boundary=' + boundary)
print('\n>>> USER: [uploads %s] (HTTP %s)' % (file_name, status), flush=True)
for reply in agent_replies(15):
    print('AGENT:', reply, flush=True)
say('done', wait_seconds=90)
