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
from urllib.parse import urlsplit, urlunsplit
import xml.etree.ElementTree as ET

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
    if r.status_code == 200:
        data = json.loads(r.text)
        respond = data.get('code')
        return respond
    else:
        respond = ''
        print("Bad code request! {}".format(r.text))
        return respond

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

def gen_mdlp_token(endpoint, clientid, clientsecret, userid, thumbprint):
    code = get_mdlp_code(endpoint, clientid, clientsecret, userid)
    sign = get_sign_csp(code, thumbprint)
    token = get_mdlp_token(endpoint, code, sign)
    return token

def get_mdlp_sscc_full_hier(endpoint, item, token, target="api/v1/reestr/sscc/full-hierarchy"):
    url = "{}/{}".format(endpoint, target)
    params = {'sscc': item}
    body = {}
    headers = {"Accept": "application/json;charset=UTF-8", "Authorization": "token {}".format(token)}
    r = requests.get(url, headers=headers, data=body, params=params)
    if r.status_code == 200:
        respond = json.loads(r.text)
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
    if r.status_code == 200:
        respond = json.loads(r.text)
        return respond
    else:
        respond = ''
        print("Bad existed sscc request! {}".format(r.text))
        return respond

def get_mdlp_income_docs(endpoint, token, count=30, doc_type="", target="api/v1/documents/income"):
    url = "{}/{}".format(endpoint, target)
    body = {"filter": {"doc_type": doc_type}, "start_from": 0, "count": count}
    headers = {"Content-Type": "application/json;charset=UTF-8", "Accept": "application/json;charset=UTF-8", "Authorization": "token {}".format(token)}
    r = requests.post(url, headers=headers, json=body)
    if r.status_code == 200:
        respond = json.loads(r.text)
        return respond.get('documents')
    else:
        respond = ''
        print("Bad income documents request! {}".format(r.text))
        return respond

def get_mdlp_outcome_docs(endpoint, token, count=30, doc_type="", target="api/v1/documents/outcome"):
    url = "{}/{}".format(endpoint, target)
    body = {"filter": {"doc_type": doc_type}, "start_from": 0, "count": count}
    headers = {"Content-Type": "application/json;charset=UTF-8", "Accept": "application/json;charset=UTF-8", "Authorization": "token {}".format(token)}
    r = requests.post(url, headers=headers, json=body)
    if r.status_code == 200:
        respond = json.loads(r.text)
        return respond.get('documents')
    else:
        respond = ''
        print("Bad income documents request! {}".format(r.text))
        return respond

def get_mdlp_document(endpoint, item, token, target="api/v1/documents"):
    url = "{}/{}/{}".format(endpoint, target, item)
    body = {}
    headers = {"Accept": "application/json;charset=UTF-8", "Authorization": "token {}".format(token)}
    r = requests.get(url, headers=headers, data=body)
    if r.status_code == 200:
        respond = json.loads(r.text)
        return respond
    else:
        respond = ''
        print("Bad document request! {}".format(r.text))
        return respond

def get_mdlp_sgtin_docs(endpoint, item, token, target="api/v1/reestr/sgtin/documents"):
    url = "{}/{}".format(endpoint, target)
    params = {'sgtin': item}
    body = {}
    headers = {"Accept": "application/json;charset=UTF-8", "Authorization": "token {}".format(token)}
    r = requests.get(url, headers=headers, data=body, params=params)
    if r.status_code == 200:
        data = json.loads(r.text)
        respond = data.get('entries')
        return respond
    else:
        respond = ''
        print("Bad documents request! {}".format(r.text))
        return respond

def get_mdlp_doc(endpoint, item, token, target="api/v1/documents/download"):
    url = "{}/{}/{}".format(endpoint, target, item)
    body = {}
    purl = list(urlsplit(url))
    headers = {"Accept": "application/json;charset=UTF-8", "Authorization": "token {}".format(token)}
    r = requests.get(url, headers=headers, data=body)
    if r.status_code == 200:
        data = json.loads(r.text)
        link = data.get('link')
        durl = list(urlsplit(link))
        durl[0] = purl[0]
        durl[1] = purl[1]
        rurl = urlunsplit(durl)
        r1 = requests.get(rurl, headers=headers, data=body)
        respond = r1.text
        return respond
    else:
        respond = ''
        print("Bad document request! {}".format(r.text))
        return respond

def find_mdlp_doc_type(docs, type):
    result = []
    for i in docs:
        if i.get('doc_type') == type:
            result.append(i.get('document_id'))
    return result

def parse_mdlp_xml_doc(doc):
    myroot = ET.fromstring(doc)
    items = []
    for i in myroot:
        dict = {}
        dict['name'] = i.tag
        dict['attr'] = i.attrib
        for j in i:
            if len(j) != 0:
                sub = {}
                for k in j:
                    sub[k.tag] = k.text
                dict[j.tag] = sub
            else:
                dict[j.tag] = j.text
        items.append(dict)
    return items

