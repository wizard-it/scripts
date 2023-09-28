from lxml import etree
from get_sscc_hierarchy_antares import get_sscc_hier_ant
import logging
import logging.handlers as handlers
import time
from logging import Formatter
from token_request import token_request, token
import requests
import json

api_url = 'http://127.0.0.1:18080'

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logHandler = handlers.RotatingFileHandler('app.log', maxBytes=50 ** 6, backupCount=10)
logHandler.setFormatter(Formatter(fmt='[%(asctime)s: %(levelname)s] %(message)s'))
logHandler.setLevel(logging.DEBUG)
logger.addHandler(logHandler)

"""
def get_sgtin_messages_mdlp_request(sgtin, retry=0):
    url = f"http://127.0.0.1:18080/api/v1/reestr/sgtin/documents"
    params = {'sgtin': f'{sgtin}'}
    # params = {'sscc': item}
    payload = {}
    # payload_json = json.dumps(payload)
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': f'token {token()}'
    }
    response = requests.request("GET", url, headers=headers, data=payload, params=params)
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
        time.sleep(10)

        return get_sgtin_messages_mdlp_request(sgtin, retry + 1)
"""
"""
def response_parser_342(response_f):
    load = json.loads(response_f)
    # doc_status = load['doc_status']
    entries = load['entries']
    # print(entries)
    for i in entries:
        if i['doc_type'] == 342:
            return i['document_id']
"""

"""
def response_parser_313(response_f):
    load = json.loads(response_f)
    # doc_status = load['doc_status']
    entries = load['entries']
    # print(entries)
    for i in entries:
        if i['doc_type'] == 313:
            return i['document_id']
"""

"""
# Get main document by it id:
def get_document_main(document_id_f):
    document = f"{api_url}/api/v1/documents/download/{document_id_f}"
    headers = {
        'Accept': 'application/json',
        f'Authorization': f'token {token()}'
    }
    response = requests.request("GET", document, headers=headers)
    logger.debug(f"Function 'get_document_main' [REQUEST_URL]: {document} "
                 f"[document_id]: {document_id_f} [REQUEST_HEADERS]: {headers}")
    # logger.debug(response.text)
    logger.debug(f"Function 'get_document_main' [REQUEST_TEXT]: {response.text}")
    # print(response.text)
    link = json.loads(response.text)
    # print('link', link["link"])
    url = link["link"]
    url = url.replace("https://api.mdlp.crpt.ru", api_url)
    # print('url', url)
    logger.debug(f"Function 'get_document_main' [REQUEST_URL]: {url} "
                 f"[REQUEST_HEADERS]: {headers}")
    response = requests.get(url, headers=headers)
    logger.debug(f"Function 'get_document_main' [REQUEST_CONTENT]: {response.content}")
    # logger.debug(response.content)
    main_f = response.content
    return main_f
    # print(main)
"""
"""
def doc_342_parser(main_xml):
    root_main = etree.fromstring(main_xml)
    doc_date = root_main.xpath('//documents/release_in_circulation/release_info/doc_date/text()')
    confirmation_num = root_main.xpath('//documents/release_in_circulation/release_info/confirmation_num/text()')
    return [doc_date[0], confirmation_num[0]]

def doc_313_parser(main_xml):
    root_main = etree.fromstring(main_xml)
    doc_date = root_main.xpath('//documents/register_product_emission/release_info/doc_date/text()')
    confirmation_num = root_main.xpath('//documents/register_product_emission/release_info/confirmation_num/text()')
    return [doc_date[0], confirmation_num[0]]
"""

def get_metadata_for_342_doc(antares_parent, cases_all):
    # antares_parent = '00959970013008662935'
    # cases_all = ['959970013008662607']
    df = get_sscc_hier_ant(antares_parent)
    # print(df)
    if not df.empty:
        victim = df.loc[(df['child_level_1_CodingRule'] == 'GS1_SSCC') & (~df['child_level_1_Serial'].isin(cases_all))]
        i = 0
        while i < len(victim) and i < 20:

            victim_serial = victim.iloc[i]['child_level_2_ntin'] + victim.iloc[i]['child_level_2_Serial']
            print('victim_serial:', victim_serial)
            logger.debug(f'victim_serial: {victim_serial}')
            response = get_sgtin_messages_mdlp_request(victim_serial)
            document_id = response_parser_342(response)
            if document_id:
                doc = get_document_main(document_id)
                if doc:
                    doc_date, confirmation_num = doc_342_parser(doc)
                    print(f'342 doc metadata: {doc_date}, {confirmation_num}')
                    logger.debug(f'342 doc metadata: {doc_date}, {confirmation_num}')
                    return [doc_date, confirmation_num]
            else:
                i += 1
                # time.sleep(1)


def get_metadata_for_313_doc(antares_parent, cases_all):
    df = get_sscc_hier_ant(antares_parent)
    if not df.empty:
        victim = df.loc[(df['child_level_1_CodingRule'] == 'GS1_SSCC') & (~df['child_level_1_Serial'].isin(cases_all))]
        i = 0
        while i < len(victim) and i < 20:

            victim_serial = victim.iloc[i]['child_level_2_ntin'] + victim.iloc[i]['child_level_2_Serial']
            print('victim_serial:', victim_serial)
            logger.debug(f'victim_serial: {victim_serial}')
            response = get_sgtin_messages_mdlp_request(victim_serial)
            document_id = response_parser_313(response)
            if document_id:
                doc = get_document_main(document_id)
                if doc:
                    doc_date, confirmation_num = doc_313_parser(doc)
                    print(f'313 doc metadata: {doc_date}, {confirmation_num}')
                    logger.debug(f'313 doc metadata: {doc_date}, {confirmation_num}')
                    return [doc_date, confirmation_num]
            else:
                i += 1
