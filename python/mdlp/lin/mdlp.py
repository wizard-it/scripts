import logging
import logging.handlers as handlers
import time
from logging import Formatter
from token_request import token_request, token
import requests
from datetime import datetime, timedelta
import os, sys
import json
# from datetime import timedelta
import base64

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
    
def token_request():
    CADES_BES = 1
    CADES_DEFAULT = 0
    CAPICOM_ENCODE_BASE64 = 0
    CAPICOM_CURRENT_USER_STORE = 2
    CAPICOM_MY_STORE = 'My'
    CAPICOM_STORE_OPEN_MAXIMUM_ALLOWED = 2

    oStore = win32com.client.Dispatch("CAdESCOM.Store")
    oStore.Open(CAPICOM_CURRENT_USER_STORE, CAPICOM_MY_STORE, CAPICOM_STORE_OPEN_MAXIMUM_ALLOWED)
    for val in oStore.Certificates:
        # print(val.SerialNumber)
        # print(val.Thumbprint)
        # if val.SerialNumber == '1EB909D100010003BCA1':
        if val.Thumbprint == ('559F01F3A05A8505B4C18968E4570FC51A3FC196').upper():
            oCert = val
    oStore.Close
    # print(oCert)

    oSigner = win32com.client.Dispatch("CAdESCOM.CPSigner")
    oSigner.Certificate = oCert
    oSigningTimeAttr = win32com.client.Dispatch("CAdESCOM.CPAttribute")
    oSigningTimeAttr.Name = 0
    oSigningTimeAttr.Value = datetime.datetime.now()
    oSigner.AuthenticatedAttributes2.Add(oSigningTimeAttr)

    url = "http://127.0.0.1:18080/api/v1/auth"

    params = {
        'client_id': 'f20f1baf-6117-4a4a-a277-7ecfe9fd8e56',
        'client_secret': '29735216-7d01-4311-9883-0e27c25a8678',
        'user_id': '559F01F3A05A8505B4C18968E4570FC51A3FC196',
        'auth_type': 'SIGNED_CODE'
    }
    win_http = win32com.client.Dispatch('WinHTTP.WinHTTPRequest.5.1')
    win_http.Open("POST", url, False)
    win_http.SetRequestHeader("Content-Type", "application/json;charset=UTF-8")
    win_http.SetRequestHeader("Accept", "application/json;charset=UTF-8")

    win_http.Send(json.dumps(params))
    win_http.WaitForResponse()
    # print(win_http.ResponseText)
    items = json.loads(win_http.ResponseText)
    CodeAuth = items['code']

    oSignedData = win32com.client.Dispatch("CAdESCOM.CadesSignedData")
    oSignedData.ContentEncoding = 1
    message = CodeAuth
    message_bytes = message.encode('ascii')
    base64_bytes = base64.b64encode(message_bytes)
    base64_message = base64_bytes.decode('ascii')
    oSignedData.Content = base64_message
    # print(CADES_BES)
    sSignedData = oSignedData.SignCades(oSigner, CADES_BES, False, CAPICOM_ENCODE_BASE64)


    url = "http://127.0.0.1:18080/api/v1/token"
    paramskey = {
      'code': CodeAuth,
      'signature': sSignedData
    }
    # print(json.dumps(paramskey))
    win_http.Open("POST", url, False)
    win_http.SetRequestHeader("Content-Type", "application/json;charset=UTF-8")
    win_http.SetRequestHeader("Accept", "application/json;charset=UTF-8")
    win_http.Send(json.dumps(paramskey))
    win_http.WaitForResponse()
    token = win_http.ResponseText
    if token:
        # print(token)
        return token


def token():
    with open(".\\token.json", "r", encoding="utf-8") as f:
        try:
            token_response_file = json.load(f)
            token_response_file = json.loads(token_response_file)
            life_time = token_response_file['life_time']
        except ValueError:
            life_time = 10
        file_creation_date = os.path.getmtime(".\\token.json")
        if datetime.datetime.fromtimestamp(file_creation_date) < (datetime.datetime.now() - datetime.timedelta(seconds=life_time)):
            token_response = token_request()
            with open(".\\token.json", "w", encoding="utf-8") as f:
                json.dump(token_response, f, ensure_ascii=False)
            token_response = json.loads(token_response)
            token_alive = token_response['token']
        else:
            # print("Is life")
            token_alive = token_response_file['token']
    # print(token_alive)
    return token_alive



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