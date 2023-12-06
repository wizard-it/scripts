import time
from datetime import datetime, timedelta
import requests
import os, sys
import subprocess
import json
import base64
from urllib.parse import urlsplit, urlunsplit
import xml.etree.ElementTree as ET
import uuid
from lxml import etree as ET
 
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

def gen_sign_csp(code, certhash):
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
    sign = gen_sign_csp(code, thumbprint)
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

def get_mdlp_doc(endpoint, item, token, target="api/v1/documents"):
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

def download_mdlp_doc(endpoint, item, token, target="api/v1/documents/download"):
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
                sum = []
                for k in j:
                    sub = {}
                    sub[k.tag] = k.text
                    sum.append(sub)
                dict[j.tag] = sum
            else:
                dict[j.tag] = j.text
    return dict

def parse_mdlp_doc_content(items):
    if type(items) is not list:
        print("ERROR content parsing: Items must be a list.")
        return None
    sum = {}
    sgtins = []
    ssccs = []
    unknowns = []
    for i in items:
        for key in i:
            match key:
                case 'sgtin':
                    v = i.get('sgtin')
                    sgtins.append(v)
                case 'sscc':
                    v = i.get('sscc')
                    ssccs.append(v)
                case _:
                    v = i.get(key)
                    unknowns.append(v)
    sum['sgtins'] = sgtins
    sum['ssccs'] = ssccs
    sum['unknowns'] = unknowns
    return sum

def upload_mdlp_doc(endpoint, doc, token, certhash, target="api/v1/documents/send"):
    message_bytes = doc.encode("UTF-8")
    base64_bytes = base64.b64encode(message_bytes)
    base64_doc = base64_bytes.decode("UTF-8")
    try:
        result = subprocess.run(["certmgr", "-list", "-thumbprint", certhash], stdout = subprocess.DEVNULL, stderr = subprocess.DEVNULL)
        return_code = result.returncode
    except:
        return_code = 1
    if return_code != 0:
        print('Certificate is wrong or not found!')
        return 1
    with open('doc.txt', 'w') as file:
        file.write(doc)
    try:
        result = subprocess.run(["csptest", "-sfsign", "-sign", "-in", "doc.txt", "-out", "doc.txt.sig", "-my", certhash, "-detached", "-base64", "-add"], stdout = subprocess.DEVNULL, stderr = subprocess.DEVNULL)
        return_code = result.returncode
    except:
        return_code = 1
    if return_code != 0:
        print('Sign generation error!')
        return ''
    with open('doc.txt.sig', 'r') as file:
        data = file.read()
        base64_sign = data.replace('\n','')
    url = "{}/{}".format(endpoint, target)
    body = {"document": base64_doc, "sign": base64_sign, "request_id": str(uuid.uuid4()), "bulk_processing": "false"}
    headers = {"Content-Type": "application/json;charset=UTF-8", "Accept": "application/json;charset=UTF-8", "Authorization": "token {}".format(token)}
    r = requests.post(url, headers=headers, json=body)
    if r.status_code == 200:
        respond = json.loads(r.text)
        return respond.get('document_id')
    else:
        print("Bad upload request! {}".format(r.text))
        return 1

def gen_mdlp_msg(action, items, itemtype, subject, parent=None, nsmap={'xsi': 'http://www.w3.org/2001/XMLSchema-instance'}):
    now_tz = datetime.today() - timedelta(hours=3)
    operation_date = now_tz.strftime('%Y-%m-%dT%H:%M:%S.%fZ')
#   913 - Withdrawal from group packing
#   914 - Inclusion in group packing
    match action:
        case 913:
            if type(items) is not list:
                print("ERROR doc generation: Items must be a list.")
                return None
            if len(items) < 1:
                print("ERROR doc generation: one or more Items is required.")
                return None
            if len(subject) < 1:
                print("ERROR doc generation: Subject is required.")
                return None
            if itemtype not in ['sscc','sgtin']:
                print("ERROR doc generation: Itemtype must be one of (sscc, sgtin).")
                return None
            env = ET.Element('documents', version="1.36", nsmap=nsmap)
            body = ET.SubElement(env, 'unit_extract', action_id="913")
            child_1 = ET.SubElement(body, 'subject_id')
            child_1.text = subject
            child_2 = ET.SubElement(body, 'operation_date')
            child_2.text = operation_date
            child_3 = ET.SubElement(body, 'content')
            for i in items:
                с = ET.SubElement(child_3, itemtype)
                с.text = i
            msg = (ET.tostring(env, pretty_print=True)).decode("UTF-8")
            return msg
        case 914:
            if type(items) is not list:
                print("ERROR doc generation: Items must be a list.")
                return None
            if len(items) < 1:
                print("ERROR doc generation: one or more Items is required.")
                return None
            if len(subject) < 1:
                print("ERROR doc generation: Subject is required.")
                return None
            if itemtype not in ['sscc','sgtin']:
                print("ERROR doc generation: Itemtype must be one of (sscc, sgtin).")
                return None
            if not parent:
                print("ERROR doc generation: Parent is required.")
                return None
            env = ET.Element('documents', version="1.36", nsmap=nsmap)
            body = ET.SubElement(env, 'unit_append', action_id="914")
            child_1 = ET.SubElement(body, 'subject_id')
            child_1.text = subject
            child_2 = ET.SubElement(body, 'operation_date')
            child_2.text = operation_date
            child_3 = ET.SubElement(body, 'sscc')
            child_3.text = parent
            child_4 = ET.SubElement(body, 'content')
            for i in items:
                с = ET.SubElement(child_4, itemtype)
                с.text = i
            msg = (ET.tostring(env, pretty_print=True)).decode("UTF-8")
            return msg
        case _:
            print("ERROR doc generation: unknown Action number.")
            return None
