import logging
import logging.handlers as handlers
import time
from logging import Formatter
from token_request import token_request, token
# from email_notification import send_email_rg_rus
import requests
import json

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logHandler = handlers.RotatingFileHandler('app.log', maxBytes=50 ** 6, backupCount=10)
logHandler.setFormatter(Formatter(fmt='[%(asctime)s: %(levelname)s] %(message)s'))
logHandler.setLevel(logging.DEBUG)
logger.addHandler(logHandler)

# ok_status = ['PROCESSED_DOCUMENT']


def check_accepted_mdlp_request(document_id, retry=0):
    url = f"http://127.0.0.1:18080/api/v1/documents/{document_id}"
    # params = {'sscc': f'{item}'}
    # params = {'sscc': item}
    payload = {}
    # payload_json = json.dumps(payload)
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': f'token {token()}'
    }
    response = requests.request("GET", url, headers=headers, data=payload)
    print(response.url, response.status_code, response.text)
    logger.debug(f"[URL]: {response.url}")
    logger.debug(f"[HEADERS]: {headers}")
    logger.debug(f"[PAYLOAD]: {payload}")
    logger.debug(f"[RESPONSE_CODE]: {response.status_code}")
    logger.debug(f"[RESPONSE]: {response.text}")
    i = 0
    limit = 20
    if response.status_code == 200:
        time.sleep(0.5)
        return response.text
    elif retry >= limit:
        return []
    else:
        print("Sleeping 1s...")
        time.sleep(5)
        i += 1
        return check_accepted_mdlp_request(document_id, retry + 1)


def accepted_response_parser(response_f):
    load = json.loads(response_f)
    # doc_status = load['doc_status']
    if load.get('processing_document_status'):
        processing_document_status = load['processing_document_status']
        if processing_document_status == 'ACCEPTED':
            return True
        elif processing_document_status == 'REJECTED':
            return False
        elif processing_document_status == 'TECH_ERROR':
            return False
        else:
            return None
    else:
        return None


def get_document_status_mdlp(id_):
    response = check_accepted_mdlp_request(id_)
    parsed = accepted_response_parser(response)
    return parsed



'''
id = '93bbdfab-5cfb-4459-963e-aa65ee1f2845'  # Accepted
# id = 'cbfc9531-06cb-4ec4-accd-23e78e19638b'  # REjected
response = check_accepted_mdlp(id)
result = accepted_response_parser(response)
print(response)
print(result)

'''