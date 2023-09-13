import logging
import logging.handlers as handlers
import time
from logging import Formatter
from token_request import token_request, token
import requests
import json


logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logHandler = handlers.RotatingFileHandler('app.log', maxBytes=50 ** 6, backupCount=10)
logHandler.setFormatter(Formatter(fmt='[%(asctime)s: %(levelname)s] %(message)s'))
logHandler.setLevel(logging.DEBUG)
logger.addHandler(logHandler)


def sgtins_by_list_request(items, retry=0):
    url = f"http://127.0.0.1:18080/api/v1/reestr/sgtin/public/sgtins-by-list"
    # params = {'sgtin': f'{sgtin}'}
    # params = {'sscc': item}
    payload = {
        "filter": {
            "sgtins": items
        }
    }
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
        print("Sleeping 5s...")
        time.sleep(5)
        return sgtins_by_list_request(items, retry + 1)


def response_parser_sgtins(response_f):
    load = json.loads(response_f)
    # doc_status = load['doc_status']
    entries = load['entries']
    print(entries)
    sgtin_included =[]
    cases = []
    for i in entries:
        if i.get('sscc'):
            sgtin_included.append(i['sgtin'])
            if i['sscc'] not in cases:
                cases.append(i['sscc'])
    return [cases, sgtin_included]


def response_parser_sscc_check(response_f):
    load = json.loads(response_f)
    # doc_status = load['doc_status']
    entries = load['entries']
    # print(entries)
    case = {}
    for i in entries:
        if i.get('sscc'):
            sscc = i['sscc']
            parent_sscc = i["parent_sscc"]
            case[sscc] = {'parent_sscc': parent_sscc}
    return case

# def get_document_status_mdlp(id_):
#     response = check_sgtin_status_mdlp_request(id_)
#     parsed = accepted_response_parser(response)
#     return parsed
'''
sgtins = {'059970013838037819037606556', '059970013838038478024828121', '059970013838035412819870245', '059970013838033082759018072', '059970013838034775882076712', '059970013838034397653373066', '059970013838032722868066671', '059970013838035106902622166', '059970013838037781015660528', '059970013838039902812059153', '059970013838034969279748559', '059970013838035995817988548', '059970013838033638060697951', '059970013838035360010721895', '059970013838035880359666738', '059970013838038005164534925', '059970013838038564802406884', '059970013838039056559074258', '059970013838034033337838607', '059970013838032469363225032', '059970013838031575735856451', '059970013838038705650811991', '059970013838031486630310978', '059970013838037298650801803', '059970013838033166503577419', '059970013838038078010925765', '059970013838031999868954050', '059970013838033884333488549', '059970013838036707571289440', '059970013838032190633432145', '059970013838034580416846772', '059970013838039063363287310', '059970013838033275319346785', '059970013838039886106614910', '059970013838031791038751074', '059970013838035342118629830', '059970013838039916583027491', '059970013838033985219424474', '059970013838033367911068322', '059970013838034167348567836'}
sgtins_list = list(sgtins)
response = sgtins_by_list_request(sgtins_list)
cases, sgtins_in_cases = response_parser_sgtins(response)
print(response)
print(len(sgtins_in_cases), sgtins_in_cases)
print(cases)
response_sscc_check = get_sscc_exists_mdlp_request(cases)
result = response_parser_sscc_check(response_sscc_check)
print(response_sscc_check)
print(result)

'''