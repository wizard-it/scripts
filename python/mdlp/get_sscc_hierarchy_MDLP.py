import logging
import logging.handlers as handlers
import time
from logging import Formatter
from token_request import token_request, token
import requests
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logHandler = handlers.RotatingFileHandler('app.log', maxBytes=50 ** 6, backupCount=10)
logHandler.setFormatter(Formatter(fmt='[%(asctime)s: %(levelname)s] %(message)s'))
logHandler.setLevel(logging.DEBUG)
logger.addHandler(logHandler)

full_hierarchy_delay = 30  # seconds


def get_mdlp_sscc_full_hier(item, full_hierarchy_last_run, retry=0):
    if (datetime.now() - full_hierarchy_last_run).total_seconds() < full_hierarchy_delay:
        print(f'Function "get_mdlp_sscc_full_hier" Sleeping 30s...')
        time.sleep(full_hierarchy_delay)
    url = "http://127.0.0.1:18080/api/v1/reestr/sscc/full-hierarchy"
    # params = {'sscc': f'{item}'}
    params = {'sscc': item}
    # print(params)
    payload = {}
    headers = {
        'Accept': 'application/json',
        'Authorization': f'token {token()}'
    }
    response = requests.request("GET", url, headers=headers, data=payload, params=params)
    # print(response)
    # print(response.status_code)
    # print(response.url)
    # print(response.text)
    logger.debug(f"[URL]: {response.url}")
    logger.debug(f"[HEADERS]: {headers}")
    logger.debug(f"[PARAMS]: {params}")
    logger.debug(f"[RESPONSE_CODE]: {response.status_code}")
    logger.debug(f"[RESPONSE]: {response.text}")
    limit = 20
    if response.status_code == 200:
        return response.text
    elif retry >= limit:
        logger.debug(f'Function "get_mdlp_sscc_full_hier" retry count reached: {retry}')
        return []
    else:
        time.sleep(5)
        print(f'Function "get_mdlp_sscc_full_hier" try retry #: {retry + 1}')
        # print('item: ', item)
        logger.debug(f'Function "get_mdlp_sscc_full_hier" try retry #: {retry + 1}')
        return get_mdlp_sscc_full_hier(item, datetime.now(), retry + 1)

'''

sscc = ['946054690009113270']
result = get_mdlp_sscc_full_hier(sscc, datetime.now())
print(result)
with open('.\\sscc_hier_17052023.txt', 'w', encoding='utf-8') as f:
    f.write(result)
print(result)
# sscc = ['959970013008533471', '946054690009109211', '959970013008533488', '959970013008533501', '959970013008533518']
# params = {'sscc': sscc}
# result = get_mdlp_sscc_full_hierarchy(sscc)

# params = {}
# for k in sscc:
#     params = {'sscc': k}
# print(params)

'''