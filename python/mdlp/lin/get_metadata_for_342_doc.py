from lxml import etree
from get_sscc_hierarchy_antares import get_sscc_hier_ant
import logging
import logging.handlers as handlers
import time
from logging import Formatter
from token_request import token_request, token
import requests
import json

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
