import logging
import logging.handlers as handlers
import time
from logging import Formatter
import requests
from datetime import datetime, timedelta
import os, sys
import subprocess
import json
import base64

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logHandler = handlers.RotatingFileHandler('app.log', maxBytes=50 ** 6, backupCount=10)
logHandler.setFormatter(Formatter(fmt='[%(asctime)s: %(levelname)s] %(message)s'))
logHandler.setLevel(logging.DEBUG)
logger.addHandler(logHandler)
   
def get_mdlp_code(endpoint, clientid, clientsecret, userid, authtype="SIGNED_CODE", target="api/v1/auth"):
    url = "{}/{}".format(endpoint, target)
    jdata = '{"client_id":"{0}", "client_secret":"{1}","user_id":"{2}","auth_type":"{3}"}'
    format_args = [clientid, clientsecret, userid, authtype]
    data = json.loads(jdata)
    body = {key: value.format(*format_args) for key, value in data.items()}
    headers = {"Content-Type": "application/json;charset=UTF-8", "Accept": "application/json;charset=UTF-8"}
    r = requests.post(url, headers=headers, json=body)
    respond = json.loads(r.text)
    code = respond.get('code')
    return code

def get_sign_csp(code, certhash):
    try:
        result = subprocess.run(["certmgr", "-list", "-thumbprint", certhash], stdout = subprocess.DEVNULL, stderr = subprocess.DEVNULL)
        return_code = result.returncode
    except:
        return_code = 1
    if return_code != 0:
        print('Certificate is wrong or not found!')
        return 1
    with open('code.txt', 'w') as file:
        file.write(code)
    try:
        result = subprocess.run(["csptest", "-sfsign", "-sign", "-in", "code.txt", "-out", "code.txt.sig", "-my", certhash, "-detached", "-base64", "-add"], stdout = subprocess.DEVNULL, stderr = subprocess.DEVNULL)
        return_code = result.returncode
    except:
        return_code = 1
    if return_code != 0:
        print('Sign generation error!')
        return ''
    with open('code.txt.sig', 'r') as file:
        data = file.read()
        sign = data.replace('\n','')
    return sign

def get_mdlp_token(endpoint, code, signature, target="api/v1/token"):
    url = "{}/{}".format(endpoint, target)
    jdata = '{"code":"{0}", "signature":"{1}"}'
    format_args = [code, signature]
    data = json.loads(jdata)
    body = {key: value.format(*format_args) for key, value in data.items()}
    headers = {"Content-Type": "application/json;charset=UTF-8", "Accept": "application/json;charset=UTF-8"}
    r = requests.post(url, headers=headers, json=body)
    respond = json.loads(r.text)
    if "token" in respond:
        token = respond.get('token')
    else:
        token = ''
        print("Bad token request! Message: {}".format(r.text))
    return token

def get_mdlp_sscc_full_hier(endpoint, item, token, target="api/v1/reestr/sscc/full-hierarchy"):
    url = "{}/{}".format(endpoint, target)
    params = {'sscc': item}
    body = {}
    headers = {"Accept": "application/json;charset=UTF-8", "Authorization": "token {}".format(token)}
    r = requests.get(url, headers=headers, data=body, params=params)
    respond = r.text
    if r.status_code == 200:
        return respond
    else:
        respond = ''
        print("Bad hierarchy request! {}".format(r.text))
        return respond

def get_mdlp_sscc_exists(endpoint, item, token, target="api/v1/reestr/sscc/sscc_check"):
    url = "{}/{}".format(endpoint, target)
    if not isinstance(item, list):
        respond = ''
        print("Item type must be list! Skipping request.")
        return respond
    body = {"sscc": item}
    headers = {"Accept": "application/json;charset=UTF-8", "Authorization": "token {}".format(token)}
    r = requests.post(url, headers=headers, json=body)
    respond = r.text
    if r.status_code == 200:
        return respond
    else:
        respond = ''
        print("Bad existed sscc request! {}".format(r.text))
        return respond
    
def check_mdlp_sscc_exist(item, response):
    if not isinstance(item, list):
        respond = ''
        print("Item type must be list! Skipping request.")
        return respond
    data = json.loads(response)
    entries = data['entries']
    failed_entries = data['failed_entries']
    if entries:
        return entries[0]['sscc'] in item
    elif failed_entries[0]['sscc'] in item:
        return False
    else:
        respond = ''
        print("Wrong comparing, check input params!")
        return respond


    
"""
def get_sscc__mdlp_request(item, retry=0):
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
"""