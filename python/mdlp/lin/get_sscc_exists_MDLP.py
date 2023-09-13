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


def get_sscc_exists_mdlp_request(item, retry=0):
    url = "http://127.0.0.1:18080/api/v1/reestr/sscc/sscc_check"
    # params = {'sscc': f'{item}'}
    # params = {'sscc': item}
    payload = {'sscc': item}
    payload_json = json.dumps(payload)
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': f'token {token()}'
    }
    response = requests.request("POST", url, headers=headers, data=payload_json)
    print(response.url, response.status_code, response.text)
    logger.debug(f"[URL]: {response.url}")
    logger.debug(f"[HEADERS]: {headers}")
    logger.debug(f"[PAYLOAD]: {payload}")
    logger.debug(f"[RESPONSE_CODE]: {response.status_code}")
    logger.debug(f"[RESPONSE]: {response.text}")
    limit = 20
    if response.status_code == 200:
        time.sleep(0.5)
        return response.text
    elif retry >= limit:
        return []
    else:
        print("Sleeping 1s...")
        time.sleep(5)
        return get_sscc_exists_mdlp_request(item, retry + 1)


def sscc_exist_parser(sscc_f, response_f):
    load = json.loads(response_f)
    entries = load['entries']
    failed_entries = load['failed_entries']
    # print(entries)
    if entries:
        return entries[0]['sscc'] in sscc_f
    elif failed_entries[0]['sscc'] in sscc_f:
        return False


def get_sscc_exists_mdlp(item):
    item = [item]
    response = get_sscc_exists_mdlp_request(item)
    parsed = sscc_exist_parser(item, response)
    return parsed


'''
sscc = ['959970013008469725']
result = get_sscc_exists_mdlp(sscc)
print(result)
with open('.\\sscc_check.txt', 'w', encoding='utf-8') as f:
    f.write(result)
'''
'''
sscc = '959970013008384240'
result = get_mdlp_sscc_full_hierarchy(sscc)
with open('.\\sscc_hier.txt', 'w', encoding='utf-8') as f:
    f.write(result)

sscc = ['959970013008533471', '946054690009109211', '959970013008533488', '959970013008533501', '959970013008533518']
params = {'sscc': sscc}
result = get_mdlp_sscc_full_hierarchy(sscc)

# params = {}
# for k in sscc:
#     params = {'sscc': k}
print(params)
'''
